defmodule Pulse.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :pulse,
     version: @version,
     elixir: "~> 1.2",
     deps: deps,
     package: package,

     name: "Pulse",
     docs: [extras: ["README.md", "CHANGELOG.md"],
            main: "readme",
            source_ref: "v#{@version}"],
     source_url: "https://github.com/heroiclabs/pulse",
     description: description]
  end

  # Application configuration.
  def application do
    [
      mod: {Pulse, []},
      applications: [:logger, :sonic],
      env: [
        directory: "pulse"
      ]
    ]
  end

  # List of dependencies.
  defp deps do
    [{:sonic, "~> 0.1"},

     # Docs
     {:ex_doc, "~> 0.11", only: :dev},
     {:earmark, "~> 0.2", only: :dev}]
  end

  # Description.
  defp description do
    """
    Service registration and discovery library for Elixir. Relies on etcd as an external service registry.
    """
  end

  # Package info.
  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
     maintainers: ["Andrei Mihu"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/heroiclabs/pulse"}]
  end

end
