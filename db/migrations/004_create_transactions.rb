Sequel.migration do
  change do
    create_table(:transactions) do
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)

      String :reference, null: false
      String :status, null: false

      Integer :amount_cents, null: false
      Integer :base_fee_cents, null: false
      Integer :delivery_fee_cents, null: false

      String :wompi_transaction_id

      foreign_key :product_id, :products, type: :uuid
      foreign_key :customer_id, :customers, type: :uuid
      foreign_key :delivery_id, :deliveries, type: :uuid

      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
