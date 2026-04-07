defmodule ResumeScreener.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ResumeScreenerWeb.Telemetry,
      ResumeScreener.Repo,
      {DNSCluster, query: Application.get_env(:resume_screener, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ResumeScreener.PubSub},
      {Nx.Serving, name: ResumeScreener.ResumeClassifier, serving: ResumeScreener.ResumeAnalysis.classifier_serving()},
      ResumeScreenerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ResumeScreener.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ResumeScreenerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
