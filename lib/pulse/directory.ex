defmodule Pulse.Directory do
  use GenServer
  require Logger

  #
  # Pulse.Directory client API functions.
  #

  def update(service, nodes_snapshot) do
    GenServer.call(__MODULE__, {:update, service, nodes_snapshot})
  end

  def get(service) do
    GenServer.call(__MODULE__, {:get, service})
  end

  #
  # Internal.
  #

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, %{"services" => %{}, "nodes" => %{}}}
  end

  def handle_info({:nodedown, node}, %{"services" => services, "nodes" => nodes}) do
    Logger.warn("Pulse.Directory unexpected disconnect from node #{node}")

    # Update the services-to-nodes and nodes-to-services mappings.
    services = Enum.into(services, %{}, fn({service, service_nodes}) ->
        {service, List.delete(service_nodes, node)}
      end)
    nodes = Map.delete(nodes, node)

    {:noreply, %{"services" => services, "nodes" => nodes}}
  end

  def handle_call({:get, service}, _from, %{"services" => services} = state) do
    {:reply, services[service] || [], state}
  end
  def handle_call({:update, service, nodes_snapshot}, _from, %{"services" => services, "nodes" => nodes}) do
    service_nodes = services[service] || []

    # Connect new nodes as needed and update the state.
    new_nodes = Pulse.Util.complement(nodes_snapshot, service_nodes)
    {service_nodes, nodes} = Enum.reduce(new_nodes, {service_nodes, nodes}, fn(new_node, {service_nodes, nodes}) ->
        node_services = nodes[new_node]
        case node_services do
          # There are known services for this node, so assume it's a new node.
          nil ->
            case Node.connect(new_node) do
              true ->
                case Node.monitor(new_node, true) do
                  true ->
                    Logger.info("Pulse.Directory connected to node #{new_node}")
                    Logger.info("Pulse.Directory node #{new_node} registered for service #{service}")
                    {[new_node | service_nodes], Map.put(nodes, new_node, [service])}
                  _ ->
                    # Don't retry connection errors, the next directory update will reconnect.
                    Logger.warn("Pulse.Directory failed to monitor node #{new_node}")
                    {service_nodes, nodes}
                end
              _ ->
                # Don't retry connection errors, the next directory update will reconnect.
                Logger.warn("Pulse.Directory failed to connect to node #{new_node}")
                {service_nodes, nodes}
            end
          # This node is already connected, possibly by another service.
          _ ->
            Logger.info("Pulse.Directory node #{new_node} registered for service #{service}")
            {[new_node | service_nodes], Map.put(nodes, new_node, [service | node_services])}
        end
      end)

    # Disconnect missing nodes as needed.
    missing_nodes = Pulse.Util.complement(service_nodes, nodes_snapshot)
    {service_nodes, nodes} = Enum.reduce(missing_nodes, {service_nodes, nodes}, fn(missing_node, {service_nodes, nodes}) ->
        node_services = nodes[missing_node]
        case node_services do
          # Theis node is currently only serving this one service, disconnect.
          [^service] ->
            Node.monitor(missing_node, false)
            Node.disconnect(missing_node)
            Logger.info("Pulse.Directory node #{missing_node} unregistered for service #{service}")
            Logger.info("Pulse.Directory disconnected node #{missing_node}")
            {List.delete(service_nodes, missing_node), Map.delete(nodes, missing_node)}
          # There are other services for this node, do not disconnect.
          _ ->
            Logger.info("Pulse.Directory node #{missing_node} unregistered for service #{service}")
            {List.delete(service_nodes, missing_node), Map.put(nodes, missing_node, List.delete(node_services, service))}
        end
      end)

    # Update the services-to-nodes mapping.
    # The nodes-to-services mapping was updated through the new_nodes and missing_nodes processing above.
    services = case service_nodes do
      [] ->
        Map.delete(services, service)
      _ ->
        Map.put(services, service, service_nodes)
    end

    {:reply, :ok, %{"services" => services, "nodes" => nodes}}
  end

end

