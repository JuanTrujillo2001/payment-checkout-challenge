require_relative "../ports/product_repository"

module Adapters
  class SequelProductRepository
    include Ports::ProductRepository

    def find_by_id(id)
      Product[id]
    end

    def update_stock(id, new_stock)
      product = Product[id]
      return nil unless product

      product.update(stock: new_stock)
      product
    end
  end
end
