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
      path = assert_patch(view)
      assert path =~ "q=Target"
      assert render(view) =~ r1.title

      view |> form("form[phx-submit='search']", %{q: "NONEXISTENT"}) |> render_submit()
      path = assert_patch(view)
      assert path =~ "q=NONEXISTENT"
      assert render(view) =~ "No resources matches"

      # Now specifically target the "Clear all filters" button which is visible
      view |> element("button", "Clear all filters") |> render_click()
      path = assert_patch(view)
      refute path =~ "q=NONEXISTENT"
    end

    test "filters by type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("input[phx-value-type='article']") |> render_click()
      path = assert_patch(view)
      assert path =~ "types[]=article"

      view |> element("input[phx-value-type='article']") |> render_click()
      path = assert_patch(view)
      refute path =~ "types[]=article"

      # Test clearing
      view |> element("input[phx-value-type='article']") |> render_click()
      assert_patch(view)
      view |> element("button[phx-click='clear-types']") |> render_click()
      path = assert_patch(view)
      refute path =~ "types[]=article"
    end

    test "filters by tag", %{conn: conn} do
      tag_fixture(name: "elixir")
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button[phx-click='filter-tag'][phx-value-tag='elixir']") |> render_click()
      path = assert_patch(view)
      assert path =~ "tag=elixir"

      view |> element("button[phx-click='clear-tag']") |> render_click()
      path = assert_patch(view)
      refute path =~ "tag=elixir"
    end

    test "reset filters sidebar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?types[]=article")
      view |> element("button", "Reset filters") |> render_click()
      path = assert_patch(view)
      refute path =~ "types"
    end

    test "deletes", %{conn: conn, user: user} do
      resource = resource_fixture(user: user)
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button[title='Delete resource'][phx-click*='#{resource.id}']")
      |> render_click()

      view |> element("button", "Continue") |> render_click()

      result = assert_redirect(view)

      path =
        case result do
          {p, _} -> p
          p -> p
        end

      assert path =~ "/"

      assert_raise Ecto.NoResultsError, fn -> Knowledge.get_resource!(resource.id) end
    end

    test "shows user resources", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("a", "View Your Resources") |> render_click()
      path = assert_patch(view)
      assert path =~ "user_id=#{user.id}"
      assert render(view) =~ "Your Resources"
    end

    test "shows resource", %{conn: conn, user: user} do
      resource = resource_fixture(user: user)
      {:ok, _view, html} = live(conn, ~p"/resources/#{resource.id}")
      assert html =~ resource.title
    end

    test "shows snippet with correct language class", %{conn: conn, user: user} do
      snippet =
        resource_fixture(user: user, type: "snippet", language: "rust", snippet: "fn main() {}")

      {:ok, _view, html} = live(conn, ~p"/resources/#{snippet.id}")
      assert html =~ "language-rust"
    end
  end

  describe "FormComponent" do
    test "creates new resource", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/new")

      view |> form("#resource-form", resource: %{type: "article"}) |> render_change()

      view
      |> form("#resource-form",
        resource: %{type: "article", title: "New", url: "http://x.com", description: "Desc"}
      )
      |> render_submit()

      result = assert_redirect(view)

      path =
        case result do
          {p, _} -> p
          p -> p
        end

      assert path =~ "/"
      assert Knowledge.list_resources(%{"q" => "New"}) |> length() == 1
    end

    test "creates new snippet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/new")

      view |> form("#resource-form", resource: %{type: "snippet"}) |> render_change()
      assert render(view) =~ "Select Language"

      view
      |> form("#resource-form",
        resource: %{
          type: "snippet",
          title: "Code",
          description: "Desc",
          snippet: "code",
          language: "elixir"
        }
      )
      |> render_submit()

      result = assert_redirect(view)

      path =
        case result do
          {p, _} -> p
          p -> p
        end

      assert path =~ "/"
      [resource] = Knowledge.list_resources(%{"q" => "Code"})
      assert resource.type == "snippet"
      assert resource.language == "elixir"
    end

    test "edits existing resource", %{conn: conn, user: user} do
      resource = resource_fixture(user: user)
      {:ok, view, _html} = live(conn, ~p"/resources/#{resource.id}/edit")

      view |> form("#resource-form", resource: %{title: "Updated Title"}) |> render_submit()

      result = assert_redirect(view)

      path =
        case result do
          {p, _} -> p
          p -> p
        end

      assert path =~ "/"
      assert Knowledge.get_resource!(resource.id).title == "Updated Title"
    end
  end

  describe "Filters Mobile" do
    test "mobile filters flow", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button[phx-click='open-mobile-filters']") |> render_click()

      view
      |> element("input[phx-click='toggle-pending-type'][phx-value-type='article']")
      |> render_click()

      view |> element("button[phx-click='apply-mobile-filters']") |> render_click()

      path = assert_patch(view)
      assert path =~ "types[]=article"
    end
  end
end
