defmodule Share.Repo.Migrations.AddLanguageToResources do
  use Ecto.Migration

  def change do
    alter table(:resources) do
      add :language, :string
    end
  end
end
