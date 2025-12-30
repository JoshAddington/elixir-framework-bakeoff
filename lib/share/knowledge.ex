defmodule Share.Knowledge do
  @moduledoc """
  The Knowledge context.
  """

  import Ecto.Query, warn: false
  alias Share.Repo

  alias Share.Knowledge.Resource
  alias Share.Knowledge.Tag

  @doc """
  Returns the list of resources with preloaded user and tags.
  Supports filtering by type and tag name.
  """
  def list_resources(filters \\ %{}) do
    Resource
    |> preload([:user, :tags])
    |> filter_by_type(filters["type"])
    |> filter_by_tag(filters["tag"])
    |> filter_by_user(filters["user_id"])
    |> filter_by_query(filters["q"])
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  defp filter_by_query(query, search_term) when is_binary(search_term) and search_term != "" do
    search_term = "%#{search_term}%"

    query
    |> join(:left, [r], t in assoc(r, :tags), as: :search_tags)
    |> where(
      [r, search_tags: t],
      ilike(r.title, ^search_term) or
        ilike(r.description, ^search_term) or
        ilike(t.name, ^search_term)
    )
    |> distinct(true)
  end

  defp filter_by_query(query, _), do: query

  defp filter_by_user(query, user_id) when is_integer(user_id) or is_binary(user_id) do
    where(query, [r], r.user_id == ^user_id)
  end

  defp filter_by_user(query, _), do: query

  defp filter_by_type(query, types) when is_list(types) and types != [] do
    where(query, [r], r.type in ^types)
  end

  defp filter_by_type(query, type) when type in ["article", "snippet", "resource"] do
    where(query, [r], r.type == ^type)
  end

  defp filter_by_type(query, _), do: query

  defp filter_by_tag(query, tag_name) when is_binary(tag_name) and tag_name != "" do
    query
    |> join(:inner, [r], t in assoc(r, :tags))
    |> where([..., t], t.name == ^tag_name)
  end

  defp filter_by_tag(query, _), do: query

  @doc """
  Gets a single resource.
  """
  def get_resource!(id), do: Resource |> preload([:user, :tags]) |> Repo.get!(id)

  @doc """
  Creates a resource.
  """
  def create_resource(attrs, tags \\ []) do
    %Resource{}
    |> Resource.changeset(attrs, tags)
    |> Repo.insert()
  end

  @doc """
  Updates a resource.
  """
  def update_resource(%Resource{} = resource, attrs, tags \\ []) do
    resource
    |> Resource.changeset(attrs, tags)
    |> Repo.update()
  end

  @doc """
  Deletes a resource.
  """
  def delete_resource(%Resource{} = resource) do
    Repo.delete(resource)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource changes.
  """
  def change_resource(%Resource{} = resource, attrs \\ %{}, tags \\ []) do
    Resource.changeset(resource, attrs, tags)
  end

  @doc """
  Returns the list of tags.
  """
  def list_tags do
    Repo.all(Tag)
  end

  @doc """
  Starts a query to get tags by name.
  """
  def get_tags_by_names(names) do
    names = Enum.map(names, &String.downcase/1)
    Repo.all(from t in Tag, where: fragment("lower(?)", t.name) in ^names)
  end

  @doc """
  Creates a tag.
  """
  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end
end
