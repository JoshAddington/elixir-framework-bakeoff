defmodule Share.Repo.Migrations.CreateResources do
  use Ecto.Migration

  def change do
    create table(:resources) do
      add :title, :string
      add :description, :text
      add :url, :string
      add :type, :string
      add :user_id, references(:users, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:resources, [:user_id])
    create index(:resources, [:type])
  end
end
