Sequel.migration do
  up do
    # Products
    alter_table(:products) do
      set_column_type :price_cents, :bigint
    end

    # Transactions
    alter_table(:transactions) do
      set_column_type :amount_cents, :bigint
      set_column_type :base_fee_cents, :bigint
      set_column_type :delivery_fee_cents, :bigint
    end
  end

  down do
    alter_table(:products) do
      set_column_type :price_cents, :integer
    end

    alter_table(:transactions) do
      set_column_type :amount_cents, :integer
      set_column_type :base_fee_cents, :integer
      set_column_type :delivery_fee_cents, :integer
    end
  end
end
