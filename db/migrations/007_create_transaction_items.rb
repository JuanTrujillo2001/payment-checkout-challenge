Sequel.migration do
  change do
    create_table(:transaction_items) do
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)
      foreign_key :transaction_id, :transactions, type: :uuid, null: false
      foreign_key :product_id, :products, type: :uuid, null: false
      Integer :quantity, null: false, default: 1
      Bignum :price_cents, null: false
      Bignum :subtotal_cents, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
