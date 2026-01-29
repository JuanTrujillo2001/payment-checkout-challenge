Sequel.migration do
  change do
    create_table(:cart_items) do
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)
      uuid :session_id, null: false, index: true
      foreign_key :product_id, :products, type: :uuid, null: false
      Integer :quantity, null: false, default: 1
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
