defmodule ShareWeb.PageController do
  use ShareWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
