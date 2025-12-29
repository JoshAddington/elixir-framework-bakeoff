defmodule ShareWeb.Router do
  use ShareWeb, :router

  import ShareWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShareWeb.Layouts, :root}
    plug :put_layout, html: {ShareWeb.Layouts, :app}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ShareWeb do
    pipe_through :browser

    live_session :default,
      on_mount: [{ShareWeb.UserAuth, :mount_current_user}],
      layout: {ShareWeb.Layouts, :app} do
      live "/", ResourceLive.Index, :index
      live "/new", ResourceLive.Index, :new
      live "/resources/:id", ResourceLive.Index, :show
      get "/login", AuthController, :login
      post "/login", AuthController, :create_session
      get "/register", AuthController, :signup
      post "/register", AuthController, :create
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ShareWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:share, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShareWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
