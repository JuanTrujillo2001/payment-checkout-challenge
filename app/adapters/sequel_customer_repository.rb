require_relative "../ports/customer_repository"

module Adapters
  class SequelCustomerRepository
    include Ports::CustomerRepository

    def create(attributes)
      Customer.create(attributes)
    end

    def find_by_id(id)
      Customer[id]
    end
  end
end
