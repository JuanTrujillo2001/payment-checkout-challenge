require "dry/monads"
require "dry/monads/do"

module UseCases
  class ProcessPayment
    include Dry::Monads[:result, :do]

    CURRENCY = "COP"

    def initialize(transaction_repo:, payment_gateway:)
      @transaction_repo = transaction_repo
      @payment_gateway = payment_gateway
    end

    def call(transaction_id:, card_data:, installments: 1)
      transaction = yield find_transaction(transaction_id)
      yield validate_pending_status(transaction)
      acceptance = yield get_acceptance_token
      token = yield tokenize_card(card_data)
      payment_source = yield create_payment_source(token, transaction, acceptance)
      wompi_transaction = yield create_wompi_transaction(transaction, payment_source, installments)
      updated_transaction = yield update_transaction_status(transaction, wompi_transaction)

      Success(build_response(updated_transaction, wompi_transaction))
    end

    private

    def find_transaction(transaction_id)
      transaction = @transaction_repo.find_by_id(transaction_id)
      return Failure(error: :transaction_not_found, message: "Transaction not found") unless transaction

      Success(transaction)
    end

    def validate_pending_status(transaction)
      return Failure(error: :invalid_status, message: "Transaction is not pending") unless transaction.status == "PENDING"

      Success(true)
    end

    def get_acceptance_token
      result = @payment_gateway.get_acceptance_token
      return Failure(error: :acceptance_token_failed, message: "Could not get acceptance token") unless result[:success]

      Success(result[:data]["acceptance_token"])
    end

    def tokenize_card(card_data)
      result = @payment_gateway.tokenize_card(card_data)
      return Failure(error: :tokenization_failed, message: result[:error]&.dig("error", "message") || "Card tokenization failed") unless result[:success]

      Success(result[:data]["id"])
    end

    def create_payment_source(token, transaction, acceptance_token)
      customer = Customer[transaction.customer_id]
      
      result = @payment_gateway.create_payment_source(
        token: token,
        customer_email: customer.email,
        acceptance_token: acceptance_token
      )

      return Failure(error: :payment_source_failed, message: result[:error]&.dig("error", "message") || "Payment source creation failed") unless result[:success]

      Success(result[:data]["id"])
    end

    def create_wompi_transaction(transaction, payment_source_id, installments)
      customer = Customer[transaction.customer_id]
      total_amount = transaction.amount_cents + transaction.base_fee_cents + transaction.delivery_fee_cents

      result = @payment_gateway.create_transaction(
        amount_cents: total_amount,
        currency: CURRENCY,
        payment_source_id: payment_source_id,
        reference: transaction.reference,
        customer_email: customer.email,
        installments: installments
      )

      return Failure(error: :wompi_transaction_failed, message: result[:error]&.dig("error", "message") || "Wompi transaction failed") unless result[:success]

      Success(result[:data])
    end

    def update_transaction_status(transaction, wompi_transaction)
      status = wompi_transaction["status"]
      wompi_id = wompi_transaction["id"]

      updated = @transaction_repo.update_status(transaction.id, status, wompi_transaction_id: wompi_id)
      return Failure(error: :update_failed, message: "Could not update transaction") unless updated

      Success(updated)
    end

    def build_response(transaction, wompi_transaction)
      {
        transaction_id: transaction.id,
        reference: transaction.reference,
        status: transaction.status.downcase,
        wompi_transaction_id: transaction.wompi_transaction_id,
        amount_cents: transaction.amount_cents,
        total_cents: transaction.amount_cents + transaction.base_fee_cents + transaction.delivery_fee_cents,
        wompi_status: wompi_transaction["status"],
        finalized_at: wompi_transaction["finalized_at"]
      }
    end
  end
end
