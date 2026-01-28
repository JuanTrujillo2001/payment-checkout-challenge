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
    payment_gateway: Adapters::WompiPaymentGateway.new
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
