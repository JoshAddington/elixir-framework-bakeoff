defmodule ShareWeb.AuthControllerTest do
  use ShareWeb.ConnCase

  import Share.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: conn, user: user}
  end

  describe "GET /login" do
    test "renders login page", %{conn: conn} do
      conn = get(conn, ~p"/login")
      assert html_response(conn, 200) =~ "Welcome Back"
    end
  end

  describe "POST /register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/register")
      assert html_response(conn, 200) =~ "Get Started"
    end
  end
end
