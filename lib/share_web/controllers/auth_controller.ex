defmodule ShareWeb.AuthController do
  use ShareWeb, :controller

  alias Share.Accounts
  alias Share.Accounts.User

  alias ShareWeb.UserAuth

  def login(conn, _params) do
    render(conn, :login, form: to_form(%{}, as: :auth))
  end

  def create_session(conn, %{"auth" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> render(:login, form: to_form(%{email: email}, as: :auth))
    end
  end

  def signup(conn, _params) do
    form = Accounts.change_user(%User{}) |> to_form()
    render(conn, :signup, form: form)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :signup, form: to_form(changeset))
    end
  end

  def logout(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
