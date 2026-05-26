defmodule IdcalWeb.Router do
  use IdcalWeb, :router

  import IdcalWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IdcalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug IdcalWeb.Locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", IdcalWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/locale/:locale", LocaleController, :update
  end

  # Other scopes may use custom stacks.
  # scope "/api", IdcalWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:idcal, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: IdcalWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", IdcalWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{IdcalWeb.UserAuth, :require_authenticated}, IdcalWeb.Locale] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      live "/profiles", ProfileLive.Index, :index
      live "/profiles/compare", ProfileLive.Compare, :compare
      live "/profiles/new", ProfileLive.Form, :new
      live "/profiles/:id", ProfileLive.Show, :show
      live "/profiles/:id/settings", ProfileLive.Form, :edit
      live "/profiles/:id/income", IncomeLive.Index, :index
      live "/profiles/:id/expenses", ExpenseLive.Index, :index
      live "/profiles/:id/goals", SavingsGoalLive.Index, :index
      live "/profiles/:id/insights", InsightsLive.Show, :show
      live "/profiles/:id/forecast", ForecastLive.Show, :show
      live "/profiles/:id/quick", QuickEntryLive.Index, :index
      live "/profiles/:id/search", SearchLive.Index, :index
      live "/profiles/:id/calendar", CalendarLive.Index, :index
      live "/profiles/:id/month/:year/:month", MonthLive.Show, :show
    end

    get "/profiles/:id/month/:year/:month/export", ExportController, :monthly_csv
    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", IdcalWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{IdcalWeb.UserAuth, :mount_current_scope}, IdcalWeb.Locale] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
