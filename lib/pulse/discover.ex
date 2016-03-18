defmodule Pulse.Discover do
  use GenServer
  require Logger

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
