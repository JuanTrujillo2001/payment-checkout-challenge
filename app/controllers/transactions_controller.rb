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
