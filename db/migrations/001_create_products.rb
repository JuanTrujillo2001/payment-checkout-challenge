Sequel.migration do
  change do
    create_table(:products) do
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)

      String :name, null: false
      String :description, text: true
      Integer :price_cents, null: false
      Integer :stock, null: false, default: 0

      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
