defmodule ShareWeb.ResourceLiveTest do
  use ShareWeb.ConnCase

  import Phoenix.LiveViewTest
  import Share.AccountsFixtures
  import Share.KnowledgeFixtures
  import Ecto.Query

  alias Share.Knowledge

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, conn: log_in_user(conn, user), user: user}
  end

  describe "Index" do
    test "lists and filters", %{conn: conn, user: user} do
      r1 = resource_fixture(user: user, title: "Target")
      {:ok, view, html} = live(conn, ~p"/")
      assert html =~ r1.title

      view |> form("form[phx-submit='search']", %{q: "Target"}) |> render_submit()
      assert_patch(view, ~p"/?q=Target")
      assert render(view) =~ r1.title

      view |> form("form[phx-submit='search']", %{q: "NONEXISTENT"}) |> render_submit()
      assert_patch(view, ~p"/?q=NONEXISTENT")
      assert render(view) =~ "No resources matches your filter"

      view |> element("button", "Clear all filters") |> render_click()
      assert_patch(view, ~p"/?")
    end

    test "filters by type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("input[phx-value-type='article']") |> render_click()
      assert_patch(view, ~p"/?types[]=article")

      view |> element("input[phx-value-type='article']") |> render_click()
      assert_patch(view, ~p"/?")

      view |> element("input[phx-value-type='article']") |> render_click()
      assert_patch(view, ~p"/?types[]=article")
      view |> element("button[phx-click='clear-types']") |> render_click()
      assert_patch(view, ~p"/?")
    end

    test "filters by tag", %{conn: conn} do
      tag_fixture(name: "elixir")
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button[phx-click='filter-tag'][phx-value-tag='elixir']") |> render_click()
      assert_patch(view, ~p"/?tag=elixir")

      view |> element("button[phx-click='clear-tag']") |> render_click()
      assert_patch(view, ~p"/?")
    end

    test "reset filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?types[]=article")
      view |> element("button[phx-click='reset-filters']") |> render_click()
      assert_patch(view, ~p"/?")
    end

    test "deletes", %{conn: conn, user: user} do
      resource = resource_fixture(user: user)
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button[title='Delete resource'][phx-click*='#{resource.id}']")
      |> render_click()

      view |> element("button", "Continue") |> render_click()

      assert_redirect(view, "/?q=&tag=&user_id=")
      assert_raise Ecto.NoResultsError, fn -> Knowledge.get_resource!(resource.id) end
    end

    test "close delete modal", %{conn: conn, user: user} do
      resource = resource_fixture(user: user)
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button[title='Delete resource'][phx-click*='#{resource.id}']")
      |> render_click()

      assert render(view) =~ "Are you sure you want to delete"
      view |> element("button", "Cancel") |> render_click()
      refute render(view) =~ "Are you sure you want to delete"
    end

    test "shows user resources", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("a", "View Your Resources") |> render_click()
      assert_patch(view, "/?user_id=#{user.id}")
      assert render(view) =~ "Your Resources"
    end

    test "shows resource", %{conn: conn, user: user} do
      resource = resource_fixture(user: user)
      {:ok, _view, html} = live(conn, ~p"/resources/#{resource.id}")
      assert html =~ resource.title
    end

    test "timestamps", %{conn: conn, user: user} do
      yesterday = NaiveDateTime.add(NaiveDateTime.utc_now(), -1, :day)
      r = resource_fixture(user: user, title: "Yesterday")

      Share.Repo.update_all(where(Share.Knowledge.Resource, id: ^r.id),
        set: [inserted_at: yesterday]
      )

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Yesterday"
    end
  end

  describe "FormComponent" do
    test "creates new resource", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/new")

      view
      |> form("#resource-form",
        resource: %{type: "article", title: "New", url: "http://x.com", description: "Desc"}
      )
      |> render_submit()

      assert_redirect(view, "/?q=&tag=&user_id=")
      assert Knowledge.list_resources(%{"q" => "New"}) |> length() == 1
    end

    test "edits existing resource", %{conn: conn, user: user} do
      resource = resource_fixture(user: user)
      {:ok, view, _html} = live(conn, ~p"/resources/#{resource.id}/edit")
      view |> form("#resource-form", resource: %{title: "Updated Title"}) |> render_submit()
      assert_redirect(view, "/?q=&tag=&user_id=")
      assert Knowledge.get_resource!(resource.id).title == "Updated Title"
    end

    test "tag interactions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/new")
      tag_fixture(name: "elixir")
      view |> element("#tag-input-field") |> render_change(%{current_tag: "el"})
      assert render(view) =~ "elixir"

      view
      |> element("button[phx-click='select-suggestion'][phx-value-tag='elixir']")
      |> render_click()

      assert render(view) =~ ~s(phx-value-tag="elixir")
      view |> element("button[phx-click='remove-tag'][phx-value-tag='elixir']") |> render_click()
      refute render(view) =~ ~s(phx-value-tag="elixir")
    end
  end

  describe "Filters Mobile" do
    test "mobile filters flow", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("button[phx-click='open-mobile-filters']") |> render_click()

      # Select multiple
      view
      |> element("input[phx-click='toggle-pending-type'][phx-value-type='article']")
      |> render_click()

      view
      |> element("input[phx-click='toggle-pending-type'][phx-value-type='snippet']")
      |> render_click()

      # Unselect snippet
      view
      |> element("input[phx-click='toggle-pending-type'][phx-value-type='snippet']")
      |> render_click()

      view |> element("button[phx-click='apply-mobile-filters']") |> render_click()
      assert_patch(view, ~p"/?types[]=article")
    end

    test "mobile filters reset", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("button[phx-click='open-mobile-filters']") |> render_click()

      view
      |> element("input[phx-click='toggle-pending-type'][phx-value-type='article']")
      |> render_click()

      view |> element("button[phx-click='reset-pending-filters']") |> render_click()
      view |> element("button[phx-click='apply-mobile-filters']") |> render_click()
      assert_patch(view, ~p"/?q=&tag=&user_id=")
    end
  end
end
