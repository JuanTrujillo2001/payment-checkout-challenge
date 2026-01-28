module Ports
  module ProductRepository
    def find_by_id(id)
      raise NotImplementedError
    end

    def update_stock(id, new_stock)
      raise NotImplementedError
    end
  end
end
