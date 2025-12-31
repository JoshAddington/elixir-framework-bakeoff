defmodule Share.Repo.Migrations.AddSnippetToResources do
  use Ecto.Migration

  def change do
    alter table(:resources) do
      add :snippet, :text
    end
  end
end
