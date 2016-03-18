defmodule Pulse do
  use Application

  @moduledoc """
  Service registration and discovery library for Elixir. Relies on etcd as an external service registry.
  """

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Pulse.Directory, [])
    ]

    # Set options and start supervisor.
    opts = [strategy: :one_for_one, name: Pulse.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
