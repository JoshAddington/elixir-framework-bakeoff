defmodule Share.Knowledge.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resources" do
    field :title, :string
    field :description, :string
    field :url, :string
    # "article", "snippet", "resource"
    field :type, :string
    field :snippet, :string
    field :language, :string
    belongs_to :user, Share.Accounts.User
    many_to_many :tags, Share.Knowledge.Tag, join_through: "resources_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource, attrs, tags \\ []) do
    resource
    |> cast(attrs, [:title, :description, :url, :type, :user_id, :snippet, :language])
    |> validate_required([:title, :description, :type, :user_id])
    |> validate_conditional_fields()
    |> put_assoc(:tags, tags)
  end

  defp validate_conditional_fields(changeset) do
    type = get_field(changeset, :type)

    case type do
      "snippet" ->
        changeset
        |> validate_required([:snippet, :language])
        |> put_change(:url, nil)

      _ ->
        changeset
        |> validate_required([:url])
        |> put_change(:snippet, nil)
        |> put_change(:language, nil)
    end
  end
end
