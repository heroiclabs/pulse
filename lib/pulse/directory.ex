defmodule Pulse.Directory do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, [services: %{}, nodes: %{}]}
  end

  def handle_call({:update, service, nodes}, _from, [services: services, nodes: nodes]) do
    existing_nodes = services[service] || []

    new_nodes = Pulse.Util.complement(nodes, existing_nodes)
    missing_nodes = Pulse.Util.complement(existing_nodes, nodes)
  end

end
