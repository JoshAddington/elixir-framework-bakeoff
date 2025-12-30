defmodule ShareWeb.ResourceLive.FormComponent do
  use ShareWeb, :live_component

  alias Share.Knowledge

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      <div class="flex flex-col gap-1">
        <h2 class="text-2xl font-bold text-slate-900">
          {if @action == :edit, do: "Edit resource", else: "Share a resource"}
        </h2>
        <p class="text-sm text-slate-500">
          {if @action == :edit,
            do: "Update your shared resource with current information",
            else: "Contribute to the knowledge base by sharing valuable content"}
        </p>
      </div>

      <.form
        for={@form}
        id="resource-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="flex flex-col gap-5"
      >
        <div class="flex flex-col gap-2">
          <label class="text-sm font-bold text-slate-700">Resource Type</label>
          <.input
            field={@form[:type]}
            type="select"
            options={[
              {"Article", "article"},
              {"Code Snippet", "snippet"},
              {"Learning Resource", "resource"}
            ]}
            prompt="Select Resource Type"
          />
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-bold text-slate-700">Title</label>
          <.input
            field={@form[:title]}
            type="text"
            placeholder="Enter a descriptive title"
          />
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-bold text-slate-700">Description</label>
          <.input
            field={@form[:description]}
            type="textarea"
            class="min-h-[100px]"
            placeholder="Provide a detailed description"
          />
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-bold text-slate-700">Tags</label>
          <div class="relative">
            <div class="flex flex-wrap items-center gap-2 p-1.5 min-h-[46px] bg-white border border-slate-200 rounded-xl focus-within:border-slate-900 focus-within:ring-4 focus-within:ring-slate-900/10 transition-all">
              <div
                :for={tag <- @selected_tags}
                class="flex items-center gap-1.5 pl-3 pr-1.5 py-1 bg-slate-900 text-white rounded-lg text-xs font-bold transition-colors"
              >
                {tag}
                <button
                  type="button"
                  phx-click="remove-tag"
                  phx-value-tag={tag}
                  phx-target={@myself}
                  class="p-0.5 rounded-md text-slate-400 hover:text-white transition-all"
                >
                  <.icon name="hero-x-mark" class="size-3 stroke-[3]" />
                </button>
              </div>
              <input
                type="text"
                name="current_tag"
                id="tag-input-field"
                value={@current_tag}
                placeholder={if Enum.empty?(@selected_tags), do: "Add tags...", else: ""}
                phx-keydown="tag-keydown"
                phx-blur="add-tag"
                phx-target={@myself}
                phx-change="tag-input"
                class="flex-1 min-w-[120px] bg-transparent border-none focus:ring-0 text-sm text-slate-900 placeholder:text-slate-400 p-1"
              />
            </div>
            
    <!-- Autocomplete Dropdown -->
            <div
              :if={!Enum.empty?(@suggested_tags)}
              class="absolute z-50 w-full mt-2 bg-white border border-slate-200 rounded-xl shadow-xl overflow-hidden py-1"
            >
              <button
                :for={{tag, index} <- Enum.with_index(@suggested_tags)}
                type="button"
                phx-click="select-suggestion"
                phx-value-tag={tag}
                phx-target={@myself}
                class={[
                  "w-full text-left px-4 py-2 text-sm transition-colors",
                  @focused_index == index && "bg-slate-900 text-white font-bold",
                  @focused_index != index && "text-slate-700 hover:bg-slate-50"
                ]}
              >
                {tag}
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <%= if Ecto.Changeset.get_field(@form.source, :type) == "snippet" do %>
            <label class="text-sm font-bold text-slate-700">Code Snippet</label>
            <div class="relative">
              <textarea
                name={@form[:url].name}
                id={@form[:url].id}
                class="w-full h-[300px] bg-[#0d1117] text-slate-300 font-mono text-sm p-4 rounded-xl border border-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-900/10 focus:border-slate-900 transition-all custom-scrollbar resize-none"
                placeholder="Paste your code snippet here..."
                spellcheck="false"
              ><%= Phoenix.HTML.Form.normalize_value("textarea", @form[:url].value) %></textarea>
              <div class="absolute top-3 right-3 px-2 py-1 rounded bg-white/10 text-[10px] font-mono text-white/50 pointer-events-none">
                CODE
              </div>
            </div>
          <% else %>
            <label class="text-sm font-bold text-slate-700">URL</label>
            <.input field={@form[:url]} type="text" placeholder="example.com/article" />
          <% end %>
        </div>

        <div class="flex items-center justify-end gap-3 mt-4">
          <.link
            patch={@patch}
            class="grow text-sm font-bold bg-white border border-slate-200 rounded-xl text-slate-500 text-center hover:text-slate-900 px-4 py-2 transition-colors"
          >
            Cancel
          </.link>
          <button
            disabled={!@is_form_valid}
            class={[
              "cursor-pointer grow bg-slate-900 text-white px-6 py-2.5 rounded-xl text-sm text-center font-bold shadow-lg shadow-slate-900/10 transition-all",
              @is_form_valid && "hover:bg-slate-800 hover:-translate-y-0.5",
              !@is_form_valid && "opacity-50 cursor-not-allowed"
            ]}
          >
            {if @action == :edit, do: "Save changes", else: "Share"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{resource: resource} = assigns, socket) do
    changeset = Knowledge.change_resource(resource)

    selected_tags =
      if Ecto.assoc_loaded?(resource.tags) do
        Enum.map(resource.tags, & &1.name)
      else
        []
      end

    all_tags =
      Knowledge.list_tags()
      |> Enum.map(& &1.name)
      |> Enum.sort()

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)
     |> assign(:selected_tags, selected_tags)
     |> assign(:current_tag, "")
     |> assign(:all_tags, all_tags)
     |> assign(:suggested_tags, [])
     |> assign(:focused_index, -1)
     |> assign(:is_form_valid, assigns.action == :edit)}
  end

  @impl true
  def handle_event("tag-input", %{"current_tag" => value}, socket) do
    suggested_tags =
      if String.trim(value) == "" do
        []
      else
        socket.assigns.all_tags
        |> Enum.filter(fn tag ->
          String.starts_with?(String.downcase(tag), String.downcase(value)) &&
            !Enum.any?(socket.assigns.selected_tags, fn s ->
              String.downcase(s) == String.downcase(tag)
            end)
        end)
        |> Enum.take(10)
      end

    {:noreply,
     socket
     |> assign(:current_tag, value)
     |> assign(:suggested_tags, suggested_tags)
     |> assign(:focused_index, -1)}
  end

  def handle_event("tag-keydown", %{"key" => "Enter"}, socket) do
    if socket.assigns.focused_index >= 0 &&
         socket.assigns.focused_index < length(socket.assigns.suggested_tags) do
      tag = Enum.at(socket.assigns.suggested_tags, socket.assigns.focused_index)
      add_tag(socket, tag)
    else
      add_tag(socket)
    end
  end

  def handle_event("tag-keydown", %{"key" => "ArrowDown"}, socket) do
    if Enum.empty?(socket.assigns.suggested_tags) do
      {:noreply, socket}
    else
      new_index = min(socket.assigns.focused_index + 1, length(socket.assigns.suggested_tags) - 1)
      {:noreply, assign(socket, :focused_index, new_index)}
    end
  end

  def handle_event("tag-keydown", %{"key" => "ArrowUp"}, socket) do
    if Enum.empty?(socket.assigns.suggested_tags) do
      {:noreply, socket}
    else
      new_index = max(socket.assigns.focused_index - 1, 0)
      {:noreply, assign(socket, :focused_index, new_index)}
    end
  end

  def handle_event("tag-keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, suggested_tags: [], focused_index: -1)}
  end

  def handle_event("tag-keydown", %{"key" => "Backspace", "value" => ""}, socket) do
    case socket.assigns.selected_tags do
      [] ->
        {:noreply, socket}

      tags ->
        new_tags = Enum.slice(tags, 0..-2//1)
        is_form_valid = socket.assigns.form.source.valid? && !Enum.empty?(new_tags)
        {:noreply, assign(socket, selected_tags: new_tags, is_form_valid: is_form_valid)}
    end
  end

  def handle_event("tag-keydown", _params, socket), do: {:noreply, socket}

  def handle_event("add-tag", _params, socket) do
    add_tag(socket)
  end

  def handle_event("select-suggestion", %{"tag" => tag}, socket) do
    add_tag(socket, tag)
  end

  def handle_event("remove-tag", %{"tag" => tag}, socket) do
    new_tags = List.delete(socket.assigns.selected_tags, tag)
    is_form_valid = socket.assigns.form.source.valid? && !Enum.empty?(new_tags)
    {:noreply, assign(socket, selected_tags: new_tags, is_form_valid: is_form_valid)}
  end

  @impl true
  def handle_event("validate", %{"resource" => resource_params}, socket) do
    changeset =
      socket.assigns.resource
      |> Knowledge.change_resource(resource_params)
      |> Map.put(:action, :validate)

    is_form_valid = changeset.valid? && !Enum.empty?(socket.assigns.selected_tags)

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign(:is_form_valid, is_form_valid)}
  end

  @impl true
  def handle_event("save", %{"resource" => resource_params}, socket) do
    # Add user_id to params for new resources
    resource_params =
      if socket.assigns.action == :new,
        do: Map.put(resource_params, "user_id", socket.assigns.current_user.id),
        else: resource_params

    save_resource(socket, socket.assigns.action, resource_params, socket.assigns.selected_tags)
  end

  defp add_tag(socket, tag_name \\ nil) do
    tag = (tag_name || socket.assigns.current_tag) |> String.trim()

    already_selected? =
      Enum.any?(socket.assigns.selected_tags, fn s ->
        String.downcase(s) == String.downcase(tag)
      end)

    if tag != "" && !already_selected? do
      new_tags = socket.assigns.selected_tags ++ [tag]
      is_form_valid = socket.assigns.form.source.valid? && !Enum.empty?(new_tags)

      {:noreply,
       socket
       |> assign(selected_tags: new_tags, current_tag: "", is_form_valid: is_form_valid)
       |> assign(suggested_tags: [], focused_index: -1)}
    else
      {:noreply, assign(socket, current_tag: "", suggested_tags: [], focused_index: -1)}
    end
  end

  defp save_resource(socket, :edit, resource_params, tag_names) do
    existing_tags = Knowledge.get_tags_by_names(tag_names)
    all_tags = resolve_tags(existing_tags, tag_names)

    case Knowledge.update_resource(socket.assigns.resource, resource_params, all_tags) do
      {:ok, _resource} ->
        {:noreply,
         socket
         |> put_flash(:info, "Resource updated successfully!")
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_resource(socket, :new, resource_params, tag_names) do
    existing_tags = Knowledge.get_tags_by_names(tag_names)
    all_tags = resolve_tags(existing_tags, tag_names)

    case Knowledge.create_resource(resource_params, all_tags) do
      {:ok, _resource} ->
        {:noreply,
         socket
         |> put_flash(:info, "New resource successfully added!")
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp resolve_tags(existing_tags, tag_names) do
    existing_names_down = Enum.map(existing_tags, &String.downcase(&1.name))

    new_tags =
      tag_names
      |> Enum.reject(fn name -> String.downcase(name) in existing_names_down end)
      |> Enum.map(fn name ->
        with {:ok, tag} <- Knowledge.create_tag(%{name: name}), do: tag
      end)
      |> Enum.filter(&match?(%Share.Knowledge.Tag{}, &1))

    existing_tags ++ new_tags
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
