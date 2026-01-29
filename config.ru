require "dotenv/load"
require "dry/monads"
require "rack/cors"

require_relative "./app/db"

use Rack::Cors do
  allow do
    origins ENV.fetch('ALLOWED_ORIGINS', '*').split(',').map(&:strip)
    resource '*', 
      headers: :any, 
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      max_age: 600
  end
end

# domain entities
require_relative "./app/domain/entities/product"
require_relative "./app/domain/entities/customer"
require_relative "./app/domain/entities/delivery"
require_relative "./app/domain/entities/transaction"
require_relative "./app/domain/entities/cart_item"
require_relative "./app/domain/entities/transaction_item"

# ports
require_relative "./app/ports/product_repository"
require_relative "./app/ports/customer_repository"
require_relative "./app/ports/delivery_repository"
require_relative "./app/ports/transaction_repository"
require_relative "./app/ports/payment_gateway"
require_relative "./app/ports/cart_repository"

# adapters
require_relative "./app/adapters/sequel_product_repository"
require_relative "./app/adapters/sequel_customer_repository"
require_relative "./app/adapters/sequel_delivery_repository"
require_relative "./app/adapters/sequel_transaction_repository"
require_relative "./app/adapters/wompi_payment_gateway"
require_relative "./app/adapters/sequel_cart_repository"

# use cases
require_relative "./app/use_cases/create_transaction"
require_relative "./app/use_cases/create_transaction_from_cart"
require_relative "./app/use_cases/process_payment"
require_relative "./app/use_cases/fulfill_transaction"

# controllers
require_relative "./app/controllers/products_controller"
require_relative "./app/controllers/transactions_controller"
require_relative "./app/controllers/cart_controller"

# Disable ALL protection for Railway deployment (CORS handles security)
Sinatra::Application.disable :protection

run Sinatra::Application
