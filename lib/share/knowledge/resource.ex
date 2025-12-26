defmodule Share.Knowledge.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resources" do
    field :title, :string
    field :description, :string
    field :url, :string
    # "article", "snippet", "resource"
    field :type, :string
    belongs_to :user, Share.Accounts.User
    many_to_many :tags, Share.Knowledge.Tag, join_through: "resources_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource, attrs, tags \\ []) do
    resource
    |> cast(attrs, [:title, :description, :url, :type, :user_id])
    |> validate_required([:title, :description, :url, :type, :user_id])
    |> put_assoc(:tags, tags)
  end
end
