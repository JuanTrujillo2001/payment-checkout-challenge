Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column :session_id, String
      add_column :fulfilled_at, DateTime
    end
  end
end
