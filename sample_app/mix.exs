defmodule SampleApp.Mixfile do
  use Mix.Project

  def project do
    [
      app: :sample_app,
      version: "0.0.1",
      elixir: "~> 1.4",
      config_path: "./config/config.exs",
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: [:phoenix, :gettext] ++ Mix.compilers,
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SampleApp.Application, []},
      extra_applications: [:logger, :runtime_tools,:eventstore, :edeliver]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.2"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:vex, "~> 0.6.0"},
      {:exconstructor, "~> 1.1"},
      {:commanded, "~> 0.16"},
      {:commanded_eventstore_adapter, "~> 0.4.0"},
      {:commanded_ecto_projections, "~> 0.6.0"},
      {:commanded_swarm_registry, "~> 0.1"},
      {:uuid, "~> 1.1"},
      {:timex, "~> 3.2"},
      {:comeonin, "~> 4.1"},
      {:bcrypt_elixir, "~> 1.0"},
      {:broker, git: "https://gitnyc.taskstream.com/administrator/broker.git"},
      {:edeliver, "~> 1.5.0"},
      {:distillery, "~> 1.0.0", warn_missing: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "event_store.reset": ["event_store.drop", "event_store.create", "event_store.init"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "test": ["ecto.create --quiet", "ecto.migrate", "test"],
      setup: [
        "event_store.reset",
        "ecto.drop",
        "ecto.create",
        "ecto.migrate",
        "run priv/repo/seeds.exs"
      ]
    ]
  end
end
