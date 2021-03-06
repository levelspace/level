defmodule Level.Repo.Migrations.CreateGroupUsers do
  use Ecto.Migration

  def change do
    create table(:group_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, on_delete: :nothing, type: :binary_id), null: false

      add :space_user_id, references(:space_users, on_delete: :nothing, type: :binary_id),
        null: false

      add :group_id, references(:groups, on_delete: :nothing, type: :binary_id), null: false

      timestamps()
    end

    create index(:group_users, [:id])
    create unique_index(:group_users, [:space_user_id, :group_id])
  end
end
