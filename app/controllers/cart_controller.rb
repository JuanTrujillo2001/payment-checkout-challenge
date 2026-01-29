require "sinatra"
require "sinatra/json"

# GET /cart/:session_id
get "/cart/:session_id" do
  content_type :json
  
  cart_repo = Adapters::SequelCartRepository.new
  product_repo = Adapters::SequelProductRepository.new
  
  items = cart_repo.get_items(params[:session_id])
  
  cart_items = items.map do |item|
    product = product_repo.find_by_id(item.product_id)
    {
      id: item.id,
      product_id: item.product_id,
      product_name: product&.name,
      product_description: product&.description,
      price_cents: product&.price_cents,
      quantity: item.quantity,
      subtotal_cents: (product&.price_cents || 0) * item.quantity,
      stock: product&.stock,
      image_url: product&.image_url
    }
  end

  total_cents = cart_items.sum { |item| item[:subtotal_cents] }

  json({
    session_id: params[:session_id],
    items: cart_items,
    items_count: cart_items.sum { |item| item[:quantity] },
    subtotal_cents: total_cents,
    base_fee_cents: 500000,
    delivery_fee_cents: 1000000,
    total_cents: total_cents + 500000 + 1000000
  })
end

# POST /cart/:session_id/items
post "/cart/:session_id/items" do
  content_type :json
  
  begin
    data = JSON.parse(request.body.read, symbolize_names: true)
  rescue JSON::ParserError
    halt 400, json({ error: "invalid_json", message: "Invalid JSON" })
  end

  product_id = data[:product_id]
  quantity = data[:quantity] || 1

  product_repo = Adapters::SequelProductRepository.new
  product = product_repo.find_by_id(product_id)

  unless product
    halt 404, json({ error: "product_not_found", message: "Product not found" })
  end

  if product.stock < quantity
    halt 422, json({ error: "insufficient_stock", message: "Insufficient stock", available: product.stock })
  end

  cart_repo = Adapters::SequelCartRepository.new
  
  # Check if adding would exceed stock
  existing = CartItem.where(session_id: params[:session_id], product_id: product_id).first
  current_qty = existing ? existing.quantity : 0
  
  if current_qty + quantity > product.stock
    halt 422, json({ 
      error: "insufficient_stock", 
      message: "Cannot add more items than available stock",
      available: product.stock,
      in_cart: current_qty
    })
  end

  item = cart_repo.add_item(params[:session_id], product_id, quantity)

  status 201
  json({
    id: item.id,
    product_id: item.product_id,
    quantity: item.quantity,
    message: "Item added to cart"
  })
end

# PUT /cart/:session_id/items/:product_id
put "/cart/:session_id/items/:product_id" do
  content_type :json
  
  begin
    data = JSON.parse(request.body.read, symbolize_names: true)
  rescue JSON::ParserError
    halt 400, json({ error: "invalid_json", message: "Invalid JSON" })
  end

  quantity = data[:quantity].to_i

  product_repo = Adapters::SequelProductRepository.new
  product = product_repo.find_by_id(params[:product_id])

  unless product
    halt 404, json({ error: "product_not_found", message: "Product not found" })
  end

  if quantity > product.stock
    halt 422, json({ error: "insufficient_stock", message: "Insufficient stock", available: product.stock })
  end

  cart_repo = Adapters::SequelCartRepository.new
  
  if quantity <= 0
    cart_repo.remove_item(params[:session_id], params[:product_id])
    json({ message: "Item removed from cart" })
  else
    item = cart_repo.update_quantity(params[:session_id], params[:product_id], quantity)
    if item
      json({ id: item.id, product_id: item.product_id, quantity: item.quantity })
    else
      halt 404, json({ error: "item_not_found", message: "Item not in cart" })
    end
  end
end

# DELETE /cart/:session_id/items/:product_id
delete "/cart/:session_id/items/:product_id" do
  content_type :json
  
  cart_repo = Adapters::SequelCartRepository.new
  cart_repo.remove_item(params[:session_id], params[:product_id])
  
  json({ message: "Item removed from cart" })
end

# DELETE /cart/:session_id
delete "/cart/:session_id" do
  content_type :json
  
  cart_repo = Adapters::SequelCartRepository.new
  cart_repo.clear(params[:session_id])
  
  json({ message: "Cart cleared" })
end
