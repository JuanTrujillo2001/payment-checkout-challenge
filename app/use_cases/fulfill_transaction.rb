require "dry/monads"
require "dry/monads/do"

module UseCases
  class FulfillTransaction
    include Dry::Monads[:result, :do]

    def initialize(transaction_repo:, product_repo:, cart_repo:)
      @transaction_repo = transaction_repo
      @product_repo = product_repo
      @cart_repo = cart_repo
    end

    def call(transaction_id:)
      transaction = yield find_transaction(transaction_id)
      yield validate_not_fulfilled(transaction)
      yield validate_approved_status(transaction)
      yield decrement_stock(transaction)
      yield clear_cart(transaction)
      yield mark_fulfilled(transaction)

      Success(transaction)
    end

    private

    def find_transaction(transaction_id)
      transaction = @transaction_repo.find_by_id(transaction_id)
      return Failure(error: :transaction_not_found, message: "Transaction not found") unless transaction

      Success(transaction)
    end

    def validate_not_fulfilled(transaction)
      return Failure(error: :already_fulfilled, message: "Transaction already fulfilled") if transaction[:fulfilled_at]

      Success(true)
    end

    def validate_approved_status(transaction)
      return Failure(error: :not_approved, message: "Transaction is not approved") unless transaction.status.upcase == "APPROVED"

      Success(true)
    end

    def decrement_stock(transaction)
      items = TransactionItem.where(transaction_id: transaction.id).all

      items.each do |item|
        product = @product_repo.find_by_id(item.product_id)
        next unless product

        new_stock = [product.stock - item.quantity, 0].max
        @product_repo.update_stock(product.id, new_stock)
      end

      Success(true)
    rescue Sequel::Error => e
      Failure(error: :stock_update_failed, message: e.message)
    end

    def clear_cart(transaction)
      return Success(true) unless transaction[:session_id]

      @cart_repo.clear(transaction[:session_id])
      Success(true)
    rescue Sequel::Error => e
      Failure(error: :cart_clear_failed, message: e.message)
    end

    def mark_fulfilled(transaction)
      @transaction_repo.mark_fulfilled(transaction.id)
      Success(true)
    rescue Sequel::Error => e
      Failure(error: :mark_fulfilled_failed, message: e.message)
    end
  end
end
