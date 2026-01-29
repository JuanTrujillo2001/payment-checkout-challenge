class TransactionItem < Sequel::Model(:transaction_items)
  many_to_one :transaction
  many_to_one :product
end
