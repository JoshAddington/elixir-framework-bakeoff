defmodule ShareWeb.ResourceLive.Index do
  use ShareWeb, :live_view

  alias Share.Knowledge

  def mount(_params, _session, socket) do
    resources = Knowledge.list_resources()
    tags = Knowledge.list_tags()

    {:ok,
     socket
     |> assign(:resources, resources)
     |> assign(:tags, tags)
     |> assign(:active_types, [])
     |> assign(:active_tag, nil)}
  end

  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)

    types =
      case params["types"] do
        nil -> []
        t when is_list(t) -> t
        t -> [t]
      end

    tag = params["tag"]
    user_id = params["user_id"]

    resources = Knowledge.list_resources(%{"type" => types, "tag" => tag, "user_id" => user_id})

    {:noreply,
     socket
     |> assign(:resources, resources)
     |> assign(:active_types, types)
     |> assign(:active_tag, tag)
     |> assign(:active_user_id, user_id)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Share Resource")
    |> assign(:resource, %Share.Knowledge.Resource{user_id: socket.assigns.current_user.id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Resources")
    |> assign(:resource, nil)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Resource")
    |> assign(:resource, Knowledge.get_resource!(id))
  end

  def handle_event("toggle-type", %{"type" => type}, socket) do
    current_types = socket.assigns.active_types

    new_types =
      if type in current_types do
        current_types -- [type]
      else
        [type | current_types]
      end

    params = %{}
    params = if new_types != [], do: Map.put(params, "types", new_types), else: params

    params =
      if socket.assigns.active_tag,
        do: Map.put(params, "tag", socket.assigns.active_tag),
        else: params

    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("clear-types", _params, socket) do
    params = if socket.assigns.active_tag, do: %{"tag" => socket.assigns.active_tag}, else: %{}
    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("filter-tag", %{"tag" => tag}, socket) do
    params =
      if socket.assigns.active_types != [],
        do: %{"types" => socket.assigns.active_types},
        else: %{}

    params = if tag == socket.assigns.active_tag, do: params, else: Map.put(params, "tag", tag)

    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("clear-tag", _params, socket) do
    params =
      if socket.assigns.active_types != [],
        do: %{"types" => socket.assigns.active_types},
        else: %{}

    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end
end
