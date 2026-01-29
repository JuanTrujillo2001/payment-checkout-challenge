module Ports
  class CartRepository
    def add_item(session_id, product_id, quantity = 1)
      raise NotImplementedError
    end

    def get_items(session_id)
      raise NotImplementedError
    end

    def update_quantity(session_id, product_id, quantity)
      raise NotImplementedError
    end

    def remove_item(session_id, product_id)
      raise NotImplementedError
    end

    def clear(session_id)
      raise NotImplementedError
    end
  end
end
