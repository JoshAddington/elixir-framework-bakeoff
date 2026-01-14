defmodule ShareWeb.ResourceLiveHeaderTest do
  use ShareWeb.ConnCase

  import Phoenix.LiveViewTest
  import Share.AccountsFixtures

  test "guest visiting index sees Discover Resources in header", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/")
    header_text = index_live |> element("h1") |> render()
    assert header_text =~ "Discover Resources"
    refute header_text =~ "Your Resources"
  end

  test "guest visiting index with user_id param sees Discover Resources in header", %{conn: conn} do
    user = user_fixture()
    {:ok, index_live, _html} = live(conn, ~p"/?user_id=#{user.id}")
    header_text = index_live |> element("h1") |> render()
    assert header_text =~ "Discover Resources"
    refute header_text =~ "Your Resources"
  end

  test "logged in user visiting index sees Discover Resources in header", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    {:ok, index_live, _html} = live(conn, ~p"/")
    header_text = index_live |> element("h1") |> render()
    assert header_text =~ "Discover Resources"
    refute header_text =~ "Your Resources"
  end

  test "logged in user viewing OWN resources sees Your Resources in header", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    {:ok, index_live, _html} = live(conn, ~p"/?user_id=#{user.id}")
    header_text = index_live |> element("h1") |> render()
    assert header_text =~ "Your Resources"
    refute header_text =~ "Discover Resources"
  end

  test "logged in user viewing OTHER resources sees Discover Resources in header", %{conn: conn} do
    me = user_fixture()
    other = user_fixture()
    conn = log_in_user(conn, me)
    {:ok, index_live, _html} = live(conn, ~p"/?user_id=#{other.id}")
    header_text = index_live |> element("h1") |> render()
    assert header_text =~ "Discover Resources"
    refute header_text =~ "Your Resources"
  end
end
