defmodule WydlmWeb.Router do
  use WydlmWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug WydlmWeb.Plugs.Visitor
    plug :put_root_layout, html: {WydlmWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WydlmWeb do
    pipe_through :browser

    live "/", QuizLive, :index
    get "/health", PageController, :health
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:wydlm, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WydlmWeb.Telemetry
    end
  end
end
