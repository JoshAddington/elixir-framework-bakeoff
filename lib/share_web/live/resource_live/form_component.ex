defmodule ShareWeb.ResourceLive.FormComponent do
  use ShareWeb, :live_component

  alias Share.Knowledge

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      <div class="flex flex-col gap-1">
        <h2 class="text-2xl font-bold text-slate-900">Share a resource</h2>
        <p class="text-slate-500">Contribute to the knowledge base by sharing valuable content</p>
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
          <div class="relative flex items-center">
            <input
              type="text"
              name="tag_input"
              value={@current_tag_value}
              placeholder="Add tags"
              class="w-full rounded-xl border-slate-200 focus:border-slate-900 focus:ring-slate-900/10 transition-all text-slate-900 placeholder:text-slate-400 pr-12"
              phx-keydown="add-tag"
              phx-key="Enter"
              phx-target={@myself}
            />
            <button
              type="button"
              phx-click="add-tag"
              phx-target={@myself}
              class="absolute right-2 p-1 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-900 transition-colors"
            >
              <.icon name="hero-plus" class="w-5 h-5" />
            </button>
          </div>

          <div class="flex flex-wrap gap-2">
            <span
              :for={tag <- @tags}
              class="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-slate-100 text-sm font-medium text-slate-700 border border-slate-200"
            >
              {tag}
              <button
                type="button"
                phx-click="remove-tag"
                phx-value-tag={tag}
                phx-target={@myself}
                class="hover:text-slate-900 flex items-center"
              >
                <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
              </button>
            </span>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-bold text-slate-700">URL</label>
          <.input field={@form[:url]} type="text" placeholder="example.com/article" />
        </div>

        <div class="flex items-center justify-end gap-3 mt-4">
          <.link
            patch={@patch}
            class="grow text-sm font-bold border border-slate-200 rounded-xl text-slate-500 text-center hover:text-slate-900 px-4 py-2 transition-colors"
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
            Share
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{resource: resource} = assigns, socket) do
    changeset = Knowledge.change_resource(resource)

    # Initialize tags_value if editing (not strictly needed for create-only but good practice)
    tags =
      if Ecto.assoc_loaded?(resource.tags) do
        resource.tags |> Enum.map(& &1.name)
      else
        []
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)
     |> assign(:tags, tags)
     |> assign(:current_tag_value, "")
     |> assign(:is_form_valid, false)}
  end

  @impl true
  def handle_event("validate", %{"resource" => resource_params} = params, socket) do
    # Capture current tag input so it persists
    current_tag = params["tag_input"] || ""

    changeset =
      socket.assigns.resource
      |> Knowledge.change_resource(resource_params)
      |> Map.put(:action, :validate)

    # Valid if changeset is valid AND there is at least one tag in the list
    # (Note: we don't count the current input stroke as a tag until added)
    is_form_valid = changeset.valid? && socket.assigns.tags != []

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign(:current_tag_value, current_tag)
     |> assign(:is_form_valid, is_form_valid)}
  end

  @impl true
  def handle_event("add-tag", _params, socket) do
    tag = String.trim(socket.assigns.current_tag_value)

    new_tags =
      if tag != "" and tag not in socket.assigns.tags do
        socket.assigns.tags ++ [tag]
      else
        socket.assigns.tags
      end

    # Re-validate form with new tags list
    is_form_valid = socket.assigns.form.source.valid? && new_tags != []

    {:noreply,
     socket
     |> assign(:tags, new_tags)
     |> assign(:current_tag_value, "")
     |> assign(:is_form_valid, is_form_valid)}
  end

  @impl true
  def handle_event("remove-tag", %{"tag" => tag_to_remove}, socket) do
    new_tags = Enum.filter(socket.assigns.tags, &(&1 != tag_to_remove))

    is_form_valid = socket.assigns.form.source.valid? && new_tags != []

    {:noreply,
     socket
     |> assign(:tags, new_tags)
     |> assign(:is_form_valid, is_form_valid)}
  end

  @impl true
  def handle_event("save", %{"resource" => resource_params}, socket) do
    save_resource(socket, socket.assigns.action, resource_params, socket.assigns.tags)
  end

  defp save_resource(socket, :new, resource_params, tag_names) do
    # We need to manually resolve tags first
    # 1. Find existing tags
    existing_tags = Knowledge.get_tags_by_names(tag_names)
    existing_names = Enum.map(existing_tags, & &1.name)

    # 2. Identify new tags
    new_names = tag_names -- existing_names

    # 3. Create new tags (simple loop for now, or insert_all but we need IDs back, loop with changesets is safer for validation)
    new_tags =
      new_names
      |> Enum.map(fn name ->
        with {:ok, tag} <- Knowledge.create_tag(%{name: name}), do: tag
      end)
      # Filter out any failures (though user might want to know)
      |> Enum.filter(&match?(%Share.Knowledge.Tag{}, &1))

    all_tags = existing_tags ++ new_tags

    # Now create resource with these TAG STRUCTS
    # BUT `create_resource` takes (attrs, tags) and calls `put_assoc(:tags, tags)`.
    # `put_assoc` works with schemas.

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

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
