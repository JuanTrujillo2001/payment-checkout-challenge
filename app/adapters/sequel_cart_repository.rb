module Adapters
  class SequelCartRepository < Ports::CartRepository
    def add_item(session_id, product_id, quantity = 1)
      existing = CartItem.where(session_id: session_id, product_id: product_id).first
      
      if existing
        existing.update(quantity: existing.quantity + quantity, updated_at: Time.now)
        existing
      else
        CartItem.create(
          session_id: session_id,
          product_id: product_id,
          quantity: quantity
        )
      end
    end

    def get_items(session_id)
      CartItem.where(session_id: session_id).all
    end

    def update_quantity(session_id, product_id, quantity)
      item = CartItem.where(session_id: session_id, product_id: product_id).first
      return nil unless item

      if quantity <= 0
        item.delete
        nil
      else
        item.update(quantity: quantity, updated_at: Time.now)
        item
      end
    end

    def remove_item(session_id, product_id)
      CartItem.where(session_id: session_id, product_id: product_id).delete
    end

    def clear(session_id)
      CartItem.where(session_id: session_id).delete
    end
  end
end
