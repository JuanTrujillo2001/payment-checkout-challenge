Sequel.migration do
  change do
    create_table(:deliveries) do
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)

      String :address, null: false
      String :city, null: false
      String :country, null: false

      foreign_key :customer_id, :customers, type: :uuid

      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
