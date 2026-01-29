require "sinatra"
require "sinatra/json"

require_relative "../domain/entities/product"

get "/products" do
  products = Product.all.map do |p|
    {
      id: p.id,
      name: p.name,
      description: p.description,
      price_cents: p.price_cents,
      stock: p.stock,
      image_url: p.image_url
    }
  end

  json products
end


get "/health" do
  json status: "ok"
end
