require_relative "../ports/transaction_repository"

module Adapters
  class SequelTransactionRepository
    include Ports::TransactionRepository

    def create(attributes)
      Transaction.create(attributes)
    end

    def find_by_id(id)
      Transaction[id]
    end

    def find_by_reference(reference)
      Transaction.where(reference: reference).first
    end

    def update_status(id, status, wompi_transaction_id: nil)
      transaction = Transaction[id]
      return nil unless transaction

      updates = { status: status }
      updates[:wompi_transaction_id] = wompi_transaction_id if wompi_transaction_id

      transaction.update(updates)
      transaction
    end

    def next_reference_number
      timestamp = Time.now.strftime("%Y%m%d%H%M%S")
      random = SecureRandom.hex(4).upcase
      "TX-#{timestamp}-#{random}"
    end

    def mark_fulfilled(id)
      transaction = Transaction[id]
      return nil unless transaction

      Transaction.where(id: id).update(fulfilled_at: Time.now)
      Transaction[id]
    end
  end
end
