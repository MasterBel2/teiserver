defmodule Central.Repo.Migrations.Achievements do
  use Ecto.Migration

  def change do
    create table(:teiserver_achievement_types) do
      add :name, :string
      add :grouping, :string

      add :icon, :text
      add :colour, :string

      add :description, :text
      add :rarity, :integer
    end

    create table(:teiserver_user_achievements, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :achievement_type_id, references(:teiserver_achievement_types, on_delete: :nothing)

      add :achieved, :boolean
      add :progress, :integer

      add :inserted_at, :utc_datetime
    end

    create index(:teiserver_user_achievements, [:user_id])
    create index(:teiserver_user_achievements, [:achievement_type_id])
  end
end
