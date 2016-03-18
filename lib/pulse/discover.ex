defmodule Pulse.Discover do
  use GenServer
  require Logger

  @moduledoc """
  Start one or more `Pulse.Discover` workers to look up registered nodes for required services.

  The module taks 3 parameters in a keyword list, for legibility:

  * `service` - A binary indicating the service name to discover.
  * `poll` - An integer indicating the number of seconds to wait between discovery refreshes.
  * `delay` - An integer indicating the number of seconds to wait before first discovery.

  ```elixir
  children = [
    worker(Pulse.Discover, [[service: "my_service", poll: 5, delay: 1]])
  ]
  ```

  Each `Pulse.Discover` worker is only responsible for one service, but you can discover multiple services by declaring more than one worker.

  ```elixir
  children = [
    worker(Pulse.Discover, [[service: "my_service", poll: 5, delay: 1]], id: MyApp.MyServiceDiscover),
    worker(Pulse.Discover, [[service: "my_other_service", poll: 5, delay: 1]], id: MyApp.MyOtherServiceDiscover)
    # ...
  ]
  ```

  The configuration options should be tuned for your application, however the values shown above are a good baseline.
  """

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def init([service: service, poll: poll, delay: delay]) do
    pid = self()

    # Schedule the first discover refresh.
    Process.send_after(pid, :discover, delay * 1000)

    {:ok, [pid: pid, service: service, poll: poll]}
  end

  def handle_info(:discover, [pid: pid, service: service, poll: poll] = state) do
    # Determine what the discover path will be.
    path = [Application.get_env(:pulse, :directory), service]

    # Execute the discover request and handle the result.
    result = Sonic.Client.dir_list(path)
    case result do
      {:ok, 200, _headers, body} ->
        nodes = Enum.map(body["node"]["nodes"] || [], fn(node) ->
            node["value"] |> String.to_atom
          end)
        Pulse.Directory.update(service, nodes)
      {:ok, 404, _headers, _body} ->
        :ok
      _ ->
        Logger.error("Pulse.Discover failed for service #{service}: #{inspect result}")
    end

    # Schedule the next discover refresh.
    Process.send_after(pid, :discover, poll * 1000)
    {:noreply, state}
  end

end
