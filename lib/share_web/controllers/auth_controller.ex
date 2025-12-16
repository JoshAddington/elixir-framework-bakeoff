defmodule ShareWeb.AuthController do
  use ShareWeb, :controller

  def login(conn, _params) do
    render(conn, :login)
  end
end
