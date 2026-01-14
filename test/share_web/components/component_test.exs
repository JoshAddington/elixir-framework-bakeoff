defmodule ShareWeb.ComponentTest do
  use ShareWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import ShareWeb.CoreComponents
  import Phoenix.Component

  test "renders flash" do
    assigns = %{flash: %{"info" => "Success"}, kind: :info}
    html = render_component(&flash/1, assigns)
    assert html =~ "Success"
  end

  test "renders button" do
    assigns = %{}

    html =
      render_component(
        fn assigns ->
          ~H"""
          <.button>Click me</.button>
          """
        end,
        assigns
      )

    assert html =~ "Click me"
  end

  test "renders header" do
    assigns = %{}

    html =
      render_component(
        fn assigns ->
          ~H"""
          <.header>Title</.header>
          """
        end,
        assigns
      )

    assert html =~ "Title"
  end

  test "renders table" do
    assigns = %{rows: [%{id: 1, name: "Alice"}]}

    html =
      render_component(
        fn assigns ->
          ~H"""
          <.table id="users" rows={@rows}>
            <:col :let={user} label="Name">{user.name}</:col>
          </.table>
          """
        end,
        assigns
      )

    assert html =~ "Alice"
  end
end
