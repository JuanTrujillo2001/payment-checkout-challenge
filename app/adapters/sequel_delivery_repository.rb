require_relative "../ports/delivery_repository"

module Adapters
  class SequelDeliveryRepository
    include Ports::DeliveryRepository

    def create(attributes)
      Delivery.create(attributes)
    end

    def find_by_id(id)
      Delivery[id]
    end
  end
end
