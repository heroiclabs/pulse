defmodule Pulse.Register do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def init([service: service, ttl: ttl, heartbeat: heartbeat, delay: delay]) do
    pid = self()

    # Schedule the first registration.
    Process.send_after(pid, :register, delay * 1000)

    {:ok, [pid: pid, service: service, ttl: ttl, heartbeat: heartbeat]}
  end

  def handle_info(:register, [pid: pid, service: service, ttl: ttl, heartbeat: heartbeat] = state) do
    # Determine what the registration path and content will be.
    id = Node.self |> to_string
    path = [Application.get_env(:pulse, :directory), service, id]

    # Execute the registration and report the result.
    result = Sonic.Client.kv_put(path, id, ttl: ttl)
    case result do
      {:ok, status, _headers, _body} when status == 200 or status == 201 ->
        :ok
      _ ->
        Logger.error("Pulse.Register for service #{service}: #{inspect result}")
    end

    # Schedule the next registration heartbeat.
    Process.send_after(pid, :register, heartbeat * 1000)
    {:noreply, state}
  end

end
