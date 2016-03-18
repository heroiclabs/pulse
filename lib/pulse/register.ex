defmodule Pulse.Register do
  use GenServer
  require Logger

  @moduledoc """
  `Pulse.Register` is responsible for service registration. To use it, declare it as a worker in your application's supervision tree.

  The module takes 4 parameters in a keyword list, for legibility:

  * `service` - A binary indicating the service name to register.
  * `ttl` - An integer indicating the number of seconds the registration should live unless refreshed.
  * `heartbeat` - An integer indicating the number of seconds to wait between registration refreshes.
  * `delay` - An integer indicating the number of seconds to wait before first registration.

  ```elixir
  children = [
    worker(Pulse.Register, [[service: "my_service", ttl: 15, heartbeat: 5, delay: 5]])
  ]
  ```

  Each `Pulse.Register` worker is only responsible for one service, but you can register the application as providing multiple services by declaring more than one worker.

  ```elixir
  children = [
    worker(Pulse.Register, [[service: "my_service", ttl: 15, heartbeat: 5, delay: 5]], id: MyApp.MyServiceRegister),
    worker(Pulse.Register, [[service: "my_other_service", ttl: 15, heartbeat: 5, delay: 5]], id: MyApp.MyOthereSrviceRegister)
    # ...
  ]
  ```

  The configuration options should be tuned for your application, however the values shown above are a good baseline.
  """

  @doc false
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
        Logger.error("Pulse.Register failed for service #{service}: #{inspect result}")
    end

    # Schedule the next registration heartbeat.
    Process.send_after(pid, :register, heartbeat * 1000)
    {:noreply, state}
  end

end
