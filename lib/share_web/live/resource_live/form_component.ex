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
          <input
            type="text"
            name="tags"
            value={@tags_value}
            placeholder="Add tags"
            class="w-full rounded-xl border-slate-200 focus:border-slate-900 focus:ring-slate-900/10 transition-all text-slate-900 placeholder:text-slate-400"
          />
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
          <button class="grow bg-slate-900 text-white px-6 py-2.5 rounded-xl text-sm text-center font-bold shadow-lg shadow-slate-900/10 hover:bg-slate-800 hover:-translate-y-0.5 transition-all">
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
    tags_value =
      if Ecto.assoc_loaded?(resource.tags) do
        resource.tags |> Enum.map(& &1.name) |> Enum.join(", ")
      else
        ""
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)
     |> assign(:tags_value, tags_value)}
  end

  @impl true
  def handle_event("validate", %{"resource" => resource_params}, socket) do
    changeset =
      socket.assigns.resource
      |> Knowledge.change_resource(resource_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"resource" => resource_params, "tags" => tags_string}, socket) do
    # Simple tag parsing: split by comma, trim, unique
    tags =
      tags_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
      # Format for create_resource/2? No, likely assumes pure strings or existing tag structs.
      |> Enum.map(&%{name: &1})

    # Wait, create_resource expects existing Tag structs or maps?
    # Looking at `Share.Knowledge.create_resource` -> `changeset` -> `Repo.insert`.
    # And `changeset` calls `put_assoc(:tags, tags)`.
    # `put_assoc` can handle maps formatted as `%{name: "tagname"}` and will create them if they don't exist?
    # Actually, `put_assoc` creates NEW records by default if maps are passed. It does NOT automatically find-or-create by generic fields.
    # We need to look up existing tags and create new ones.

    save_resource(socket, socket.assigns.action, resource_params, tags)
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
         |> put_flash(:info, "Resource created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
