defmodule IdcalWeb.PageController do
  use IdcalWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
