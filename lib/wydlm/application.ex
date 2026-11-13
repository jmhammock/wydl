defmodule Wydlm.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WydlmWeb.Telemetry,
      Wydlm.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:wydlm, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:wydlm, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Wydlm.PubSub},
      # Start a worker by calling: Wydlm.Worker.start_link(arg)
      # {Wydlm.Worker, arg},
      # Start to serve requests, typically the last entry
      WydlmWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wydlm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WydlmWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # In a release, migrations are applied explicitly by `bin/start` (via
    # `Wydlm.Release.migrate`) before the server boots. In dev/test they are
    # run by this supervised child.
    System.get_env("RELEASE_NAME") != nil
  end
end
