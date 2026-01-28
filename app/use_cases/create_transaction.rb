require "dry/monads"
require "dry/monads/do"

module UseCases
  class CreateTransaction
    include Dry::Monads[:result, :do]

    BASE_FEE_CENTS = 5000
    DELIVERY_FEE_CENTS = 10000

    def initialize(product_repo:, customer_repo:, delivery_repo:, transaction_repo:)
      @product_repo = product_repo
      @customer_repo = customer_repo
      @delivery_repo = delivery_repo
      @transaction_repo = transaction_repo
    end

    def call(params)
      product = yield validate_product(params[:product_id])
      yield validate_stock(product, params[:quantity] || 1)
      customer = yield create_customer(params[:customer])
      delivery = yield create_delivery(customer, params[:delivery])
      transaction = yield create_transaction(product, customer, delivery, params[:quantity] || 1)
      yield decrement_stock(product, params[:quantity] || 1)

      Success(build_response(transaction))
    end

    private

    def validate_product(product_id)
      product = @product_repo.find_by_id(product_id)
      return Failure(error: :product_not_found, message: "Product not found") unless product

      Success(product)
    end

    def validate_stock(product, quantity)
      return Failure(error: :insufficient_stock, message: "Insufficient stock") if product.stock < quantity

      Success(true)
    end

    def create_customer(customer_params)
      customer = @customer_repo.create(
        full_name: customer_params[:full_name],
        identity_document: customer_params[:identity_document],
        email: customer_params[:email],
        phone: customer_params[:phone]
      )

      Success(customer)
    rescue Sequel::Error => e
      Failure(error: :customer_creation_failed, message: e.message)
    end

    def create_delivery(customer, delivery_params)
      delivery = @delivery_repo.create(
        customer_id: customer.id,
        address: delivery_params[:address],
        city: delivery_params[:city],
        country: delivery_params[:country]
      )

      Success(delivery)
    rescue Sequel::Error => e
      Failure(error: :delivery_creation_failed, message: e.message)
    end

    def create_transaction(product, customer, delivery, quantity)
      amount_cents = product.price_cents * quantity
      reference = @transaction_repo.next_reference_number

      transaction = @transaction_repo.create(
        reference: reference,
        status: "PENDING",
        amount_cents: amount_cents,
        base_fee_cents: BASE_FEE_CENTS,
        delivery_fee_cents: DELIVERY_FEE_CENTS,
        product_id: product.id,
        customer_id: customer.id,
        delivery_id: delivery.id
      )

      Success(transaction)
    rescue Sequel::Error => e
      Failure(error: :transaction_creation_failed, message: e.message)
    end

    def decrement_stock(product, quantity)
      new_stock = product.stock - quantity
      @product_repo.update_stock(product.id, new_stock)

      Success(true)
    rescue Sequel::Error => e
      Failure(error: :stock_update_failed, message: e.message)
    end

    def build_response(transaction)
      {
        transaction_id: transaction.id,
        reference: transaction.reference,
        status: transaction.status.downcase,
        amount_cents: transaction.amount_cents,
        base_fee_cents: transaction.base_fee_cents,
        delivery_fee_cents: transaction.delivery_fee_cents,
        total_cents: transaction.amount_cents + transaction.base_fee_cents + transaction.delivery_fee_cents
      }
    end
  end
end
