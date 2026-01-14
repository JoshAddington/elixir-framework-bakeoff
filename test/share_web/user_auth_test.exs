defmodule ShareWeb.UserAuthTest do
  use ShareWeb.ConnCase, async: true

  alias ShareWeb.UserAuth
  import Share.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: fetch_session(conn), user: user}
  end

  describe "log_in_user/2" do
    test "stores the user_id in the session", %{conn: conn, user: user} do
      conn = UserAuth.log_in_user(conn, user)
      # UserAuth.log_in_user redirects, session is set in the redirected conn?
      # Actually it returns a conn with session set.
      assert get_session(conn, :user_id) == user.id
    end
  end

  describe "log_out_user/1" do
    test "clears the session", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user_id, user.id)
        |> UserAuth.log_out_user()

      refute get_session(conn, :user_id)
    end
  end

  describe "fetch_current_user/2" do
    test "assigns current_user if user_id is in session", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user_id, user.id)
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
    end
  end

  describe "on_mount/4" do
    test "assigns current_user to socket", %{user: user} do
      session = %{"user_id" => user.id}
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      {:cont, socket} = UserAuth.on_mount(:mount_current_user, %{}, session, socket)
      assert socket.assigns.current_user.id == user.id
    end
  end
end
