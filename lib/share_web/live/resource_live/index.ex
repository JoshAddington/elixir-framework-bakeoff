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
     |> assign(:active_tag, nil)
     |> assign(:active_user_id, nil)
     |> assign(:search_query, nil)
     |> assign(:deleting_resource, nil)}
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
    query = params["q"]

    current_filters = %{
      "types" => types,
      "tag" => tag,
      "user_id" => user_id,
      "q" => query
    }

    resources = Knowledge.list_resources(current_filters)

    {:noreply,
     socket
     |> assign(:resources, resources)
     |> assign(:active_types, types)
     |> assign(:active_tag, tag)
     |> assign(:active_user_id, user_id)
     |> assign(:search_query, query)
     |> assign(:current_filters, current_filters)}
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

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Resource")
    |> assign(:resource, Knowledge.get_resource!(id))
  end

  def handle_event("open-delete-modal", %{"id" => id}, socket) do
    resource = Knowledge.get_resource!(id)
    {:noreply, assign(socket, :deleting_resource, resource)}
  end

  def handle_event("close-delete-modal", _params, socket) do
    {:noreply, assign(socket, :deleting_resource, nil)}
  end

  def handle_event("delete", _params, socket) do
    resource = socket.assigns.deleting_resource
    {:ok, _} = Knowledge.delete_resource(resource)

    {:noreply,
     socket
     |> assign(:deleting_resource, nil)
     |> put_flash(:info, "Resource deleted!")
     |> push_navigate(to: ~p"/?#{socket.assigns.current_filters}")}
  end

  def handle_event("toggle-type", %{"type" => type}, socket) do
    current_types = socket.assigns.active_types

    new_types =
      if type in current_types do
        current_types -- [type]
      else
        [type | current_types]
      end

    params = socket.assigns.current_filters |> Map.put("types", new_types)
    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("clear-types", _params, socket) do
    params = socket.assigns.current_filters |> Map.delete("types")
    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("filter-tag", %{"tag" => tag}, socket) do
    params = socket.assigns.current_filters
    params = if tag == socket.assigns.active_tag, do: params, else: Map.put(params, "tag", tag)
    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("clear-tag", _params, socket) do
    params = socket.assigns.current_filters |> Map.delete("tag")
    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("reset-filters", _params, socket) do
    # Only keep user_id when resetting filters, effectively staying in "Your Resources" if already there
    params =
      if socket.assigns.active_user_id,
        do: %{"user_id" => socket.assigns.active_user_id},
        else: %{}

    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  def handle_event("search", %{"q" => query}, socket) do
    params = socket.assigns.current_filters |> Map.put("q", query)
    {:noreply, push_patch(socket, to: ~p"/?#{params}", replace: true)}
  end

  defp format_timestamp(dt) do
    today = Date.utc_today()
    inserted_date = NaiveDateTime.to_date(dt)
    diff = Date.diff(today, inserted_date)

    cond do
      diff <= 0 -> "Today"
      diff == 1 -> "Yesterday"
      diff < 7 -> "#{diff} days ago"
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end
end
