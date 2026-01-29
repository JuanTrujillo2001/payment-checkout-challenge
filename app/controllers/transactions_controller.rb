require "sinatra"
require "sinatra/json"
require "json"

post "/transactions" do
  content_type :json

  begin
    body = JSON.parse(request.body.read, symbolize_names: true)
  rescue JSON::ParserError
    halt 400, json(error: "invalid_json", message: "Invalid JSON body")
  end

  use_case = UseCases::CreateTransaction.new(
    product_repo: Adapters::SequelProductRepository.new,
    customer_repo: Adapters::SequelCustomerRepository.new,
    delivery_repo: Adapters::SequelDeliveryRepository.new,
    transaction_repo: Adapters::SequelTransactionRepository.new
  )

  result = use_case.call(body)

  case result
  when Dry::Monads::Success
    status 201
    json result.value!
  when Dry::Monads::Failure
    error_data = result.failure
    status_code = case error_data[:error]
                  when :product_not_found then 404
                  when :insufficient_stock then 422
                  else 400
                  end
    status status_code
    json error_data
  end
end

post "/transactions/from-cart" do
  content_type :json

  begin
    body = JSON.parse(request.body.read, symbolize_names: true)
  rescue JSON::ParserError
    halt 400, json(error: "invalid_json", message: "Invalid JSON body")
  end

  use_case = UseCases::CreateTransactionFromCart.new(
    cart_repo: Adapters::SequelCartRepository.new,
    product_repo: Adapters::SequelProductRepository.new,
    customer_repo: Adapters::SequelCustomerRepository.new,
    delivery_repo: Adapters::SequelDeliveryRepository.new,
    transaction_repo: Adapters::SequelTransactionRepository.new
  )

  result = use_case.call(body)

  case result
  when Dry::Monads::Success
    status 201
    json result.value!
  when Dry::Monads::Failure
    error_data = result.failure
    status_code = case error_data[:error]
                  when :empty_cart then 422
                  when :insufficient_stock then 422
                  else 400
                  end
    status status_code
    json error_data
  end
end

get "/transactions/reference/:reference" do
  content_type :json

  transaction_repo = Adapters::SequelTransactionRepository.new
  transaction = transaction_repo.find_by_reference(params[:reference])

  unless transaction
    halt 404, json(error: :transaction_not_found, message: "Transaction not found")
  end

  current_status = transaction.status
  wompi_status = transaction.status
  finalized_at = nil

  # Si tiene wompi_transaction_id, consultar estado actualizado en Wompi
  if transaction.wompi_transaction_id
    payment_gateway = Adapters::WompiPaymentGateway.new
    result = payment_gateway.get_transaction(transaction.wompi_transaction_id)

    if result[:success]
      wompi_data = result[:data]
      wompi_status = wompi_data["status"]
      finalized_at = wompi_data["finalized_at"]

      # Actualizar en BD si cambió el estado
      if transaction.status != wompi_status
        transaction_repo.update_status(transaction.id, wompi_status)
        current_status = wompi_status
      end
    end
  end

  customer = Customer[transaction.customer_id]
  
  # Obtener todos los items de la transacción
  transaction_items = TransactionItem.where(transaction_id: transaction.id).all
  
  items = transaction_items.map do |item|
    product = Product[item.product_id]
    {
      product_id: item.product_id,
      product_name: product&.name,
      quantity: item.quantity,
      price_cents: item.price_cents,
      subtotal_cents: item.subtotal_cents
    }
  end

  # Si no hay items en la tabla nueva, usar el producto legacy
  if items.empty? && transaction.product_id
    product = Product[transaction.product_id]
    items = [{
      product_id: transaction.product_id,
      product_name: product&.name,
      quantity: 1,
      price_cents: transaction.amount_cents,
      subtotal_cents: transaction.amount_cents
    }]
  end

  json(
    transaction_id: transaction.id,
    reference: transaction.reference,
    status: current_status.downcase,
    amount_cents: transaction.amount_cents,
    base_fee_cents: transaction.base_fee_cents,
    delivery_fee_cents: transaction.delivery_fee_cents,
    total_cents: transaction.amount_cents + transaction.base_fee_cents + transaction.delivery_fee_cents,
    wompi_transaction_id: transaction.wompi_transaction_id,
    wompi_status: wompi_status,
    finalized_at: finalized_at,
    created_at: transaction.created_at,
    customer: customer ? {
      full_name: customer.full_name,
      email: customer.email
    } : nil,
    items: items
  )
end

get "/transactions/:id" do
  content_type :json

  transaction_repo = Adapters::SequelTransactionRepository.new
  transaction = transaction_repo.find_by_id(params[:id])

  if transaction
    json(
      transaction_id: transaction.id,
      reference: transaction.reference,
      status: transaction.status.downcase,
      amount_cents: transaction.amount_cents,
      base_fee_cents: transaction.base_fee_cents,
      delivery_fee_cents: transaction.delivery_fee_cents,
      total_cents: transaction.amount_cents + transaction.base_fee_cents + transaction.delivery_fee_cents,
      wompi_transaction_id: transaction.wompi_transaction_id
    )
  else
    status 404
    json(error: :transaction_not_found, message: "Transaction not found")
  end
end

post "/transactions/:id/pay" do
  content_type :json

  begin
    body = JSON.parse(request.body.read, symbolize_names: true)
  rescue JSON::ParserError
    halt 400, json(error: "invalid_json", message: "Invalid JSON body")
  end

  use_case = UseCases::ProcessPayment.new(
    transaction_repo: Adapters::SequelTransactionRepository.new,
    payment_gateway: Adapters::WompiPaymentGateway.new,
    product_repo: Adapters::SequelProductRepository.new,
    cart_repo: Adapters::SequelCartRepository.new
  )

  result = use_case.call(
    transaction_id: params[:id],
    card_data: body[:card],
    installments: body[:installments] || 1
  )

  case result
  when Dry::Monads::Success
    status 200
    json result.value!
  when Dry::Monads::Failure
    error_data = result.failure
    status_code = case error_data[:error]
                  when :transaction_not_found then 404
                  when :invalid_status then 422
                  when :tokenization_failed then 400
                  else 400
                  end
    status status_code
    json error_data
  end
end

get "/transactions/:id/status" do
  content_type :json

  transaction_repo = Adapters::SequelTransactionRepository.new
  transaction = transaction_repo.find_by_id(params[:id])

  unless transaction
    halt 404, json(error: :transaction_not_found, message: "Transaction not found")
  end

  unless transaction.wompi_transaction_id
    halt 422, json(error: :not_processed, message: "Transaction has not been processed with Wompi yet")
  end

  payment_gateway = Adapters::WompiPaymentGateway.new
  result = payment_gateway.get_transaction(transaction.wompi_transaction_id)

  unless result[:success]
    halt 502, json(error: :wompi_error, message: "Could not fetch status from Wompi")
  end

  wompi_data = result[:data]
  new_status = wompi_data["status"]

  if transaction.status != new_status
    transaction_repo.update_status(transaction.id, new_status)
    
    # Si cambió a APPROVED y no está fulfilled, ejecutar fulfillment
    if new_status.upcase == "APPROVED" && transaction[:fulfilled_at].nil?
      fulfill_use_case = UseCases::FulfillTransaction.new(
        transaction_repo: transaction_repo,
        product_repo: Adapters::SequelProductRepository.new,
        cart_repo: Adapters::SequelCartRepository.new
      )
      fulfill_use_case.call(transaction_id: transaction.id)
    end
  end

  json(
    transaction_id: transaction.id,
    reference: transaction.reference,
    status: new_status.downcase,
    wompi_transaction_id: transaction.wompi_transaction_id,
    wompi_status: new_status,
    payment_method_type: wompi_data["payment_method_type"],
    finalized_at: wompi_data["finalized_at"],
    status_message: wompi_data["status_message"]
  )
end
