require "dotenv/load"
require "dry/monads"

require_relative "./app/db"

# domain entities
require_relative "./app/domain/entities/product"
require_relative "./app/domain/entities/customer"
require_relative "./app/domain/entities/delivery"
require_relative "./app/domain/entities/transaction"

# ports
require_relative "./app/ports/product_repository"
require_relative "./app/ports/customer_repository"
require_relative "./app/ports/delivery_repository"
require_relative "./app/ports/transaction_repository"
require_relative "./app/ports/payment_gateway"

# adapters
require_relative "./app/adapters/sequel_product_repository"
require_relative "./app/adapters/sequel_customer_repository"
require_relative "./app/adapters/sequel_delivery_repository"
require_relative "./app/adapters/sequel_transaction_repository"
require_relative "./app/adapters/wompi_payment_gateway"

# use cases
require_relative "./app/use_cases/create_transaction"
require_relative "./app/use_cases/process_payment"

# controllers
require_relative "./app/controllers/products_controller"
require_relative "./app/controllers/transactions_controller"

run Sinatra::Application
