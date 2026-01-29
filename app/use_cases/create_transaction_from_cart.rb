require "dry/monads"
require "dry/monads/do"

module UseCases
  class CreateTransactionFromCart
    include Dry::Monads[:result, :do]

    BASE_FEE_CENTS = 500000
    DELIVERY_FEE_CENTS = 1000000

    def initialize(cart_repo:, product_repo:, customer_repo:, delivery_repo:, transaction_repo:)
      @cart_repo = cart_repo
      @product_repo = product_repo
      @customer_repo = customer_repo
      @delivery_repo = delivery_repo
      @transaction_repo = transaction_repo
    end

    def call(params)
      session_id = params[:session_id]
      cart_items = yield validate_cart(session_id)
      yield validate_all_stock(cart_items)
      customer = yield create_customer(params[:customer])
      delivery = yield create_delivery(customer, params[:delivery])
      transaction = yield create_transaction(cart_items, customer, delivery, session_id)
      # NOTE: Stock y carrito se actualizan DESPUÉS de que Wompi apruebe el pago (en FulfillTransaction)

      Success(build_response(transaction, cart_items))
    end

    private

    def validate_cart(session_id)
      items = @cart_repo.get_items(session_id)
      return Failure(error: :empty_cart, message: "Cart is empty") if items.empty?

      Success(items)
    end

    def validate_all_stock(cart_items)
      cart_items.each do |item|
        product = @product_repo.find_by_id(item.product_id)
        if product.nil? || product.stock < item.quantity
          return Failure(
            error: :insufficient_stock,
            message: "Insufficient stock for #{product&.name || 'unknown product'}",
            product_id: item.product_id
          )
        end
      end

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

    def create_transaction(cart_items, customer, delivery, session_id)
      amount_cents = calculate_subtotal(cart_items)
      reference = @transaction_repo.next_reference_number

      first_item = cart_items.first

      transaction = @transaction_repo.create(
        reference: reference,
        status: "PENDING",
        amount_cents: amount_cents,
        base_fee_cents: BASE_FEE_CENTS,
        delivery_fee_cents: DELIVERY_FEE_CENTS,
        product_id: first_item.product_id,
        customer_id: customer.id,
        delivery_id: delivery.id,
        session_id: session_id
      )

      # Guardar todos los items de la transacción
      cart_items.each do |item|
        product = @product_repo.find_by_id(item.product_id)
        TransactionItem.create(
          transaction_id: transaction.id,
          product_id: item.product_id,
          quantity: item.quantity,
          price_cents: product.price_cents,
          subtotal_cents: product.price_cents * item.quantity
        )
      end

      Success(transaction)
    rescue Sequel::Error => e
      Failure(error: :transaction_creation_failed, message: e.message)
    end

    def calculate_subtotal(cart_items)
      cart_items.sum do |item|
        product = @product_repo.find_by_id(item.product_id)
        (product&.price_cents || 0) * item.quantity
      end
    end

    def decrement_all_stock(cart_items)
      cart_items.each do |item|
        product = @product_repo.find_by_id(item.product_id)
        new_stock = product.stock - item.quantity
        @product_repo.update_stock(product.id, new_stock)
      end

      Success(true)
    rescue Sequel::Error => e
      Failure(error: :stock_update_failed, message: e.message)
    end

    def clear_cart(session_id)
      @cart_repo.clear(session_id)
      Success(true)
    end

    def build_response(transaction, cart_items)
      items_detail = cart_items.map do |item|
        product = @product_repo.find_by_id(item.product_id)
        {
          product_id: item.product_id,
          product_name: product&.name,
          quantity: item.quantity,
          price_cents: product&.price_cents,
          subtotal_cents: (product&.price_cents || 0) * item.quantity
        }
      end

      {
        transaction_id: transaction.id,
        reference: transaction.reference,
        status: transaction.status.downcase,
        items: items_detail,
        amount_cents: transaction.amount_cents,
        base_fee_cents: transaction.base_fee_cents,
        delivery_fee_cents: transaction.delivery_fee_cents,
        total_cents: transaction.amount_cents + transaction.base_fee_cents + transaction.delivery_fee_cents
      }
    end
  end
end
