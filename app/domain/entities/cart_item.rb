class CartItem < Sequel::Model(:cart_items)
  many_to_one :product
end
