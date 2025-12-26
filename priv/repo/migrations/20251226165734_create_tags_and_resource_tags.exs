defmodule Share.Repo.Migrations.CreateTagsAndResourceTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:name])

    create table(:resources_tags, primary_key: false) do
      add :resource_id, references(:resources, on_delete: :delete_all)
      add :tag_id, references(:tags, on_delete: :delete_all)
    end

    create index(:resources_tags, [:resource_id])
    create index(:resources_tags, [:tag_id])
    create unique_index(:resources_tags, [:resource_id, :tag_id])
  end
end
