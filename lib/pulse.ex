defmodule Pulse do
  use Application

  @moduledoc """
  Service registration and discovery library for Elixir.
  """

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Pulse.Directory, []),
      worker(Pulse.Register, [[service: "test1", ttl: 15, heartbeat: 5, delay: 5]], id: Test.Test1Register),
      worker(Pulse.Register, [[service: "test2", ttl: 15, heartbeat: 5, delay: 5]], id: Test.Test2Register),
      worker(Pulse.Discover, [[service: "test1", ttl: 3, delay: 1]], id: Test.Test1Discover)
    ]

    # Set options and start supervisor.
    opts = [strategy: :one_for_one, name: Pulse.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
