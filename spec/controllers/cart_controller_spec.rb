require 'spec_helper'

RSpec.describe 'Cart Controller' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  let(:session_id) { SecureRandom.uuid }
  let(:product_id) { SecureRandom.uuid }

  let(:product) do
    instance_double('Product', id: product_id, name: 'Test Product', description: 'Desc', price_cents: 150_000, stock: 10)
  end

  let(:cart_item) do
    instance_double('CartItem', id: 'item-uuid', product_id: product_id, quantity: 2)
  end

  describe 'GET /cart/:session_id' do
    before do
      cart_repo = instance_double(Adapters::SequelCartRepository)
      product_repo = instance_double(Adapters::SequelProductRepository)

      allow(Adapters::SequelCartRepository).to receive(:new).and_return(cart_repo)
      allow(Adapters::SequelProductRepository).to receive(:new).and_return(product_repo)
      allow(cart_repo).to receive(:get_items).with(session_id).and_return([cart_item])
      allow(product_repo).to receive(:find_by_id).with(product_id).and_return(product)
    end

    it 'returns 200 status' do
      get "/cart/#{session_id}"

      expect(last_response.status).to eq(200)
    end

    it 'returns cart items with product details' do
      get "/cart/#{session_id}"

      body = JSON.parse(last_response.body)
      expect(body['items'].length).to eq(1)
      expect(body['items'][0]['product_name']).to eq('Test Product')
      expect(body['items'][0]['quantity']).to eq(2)
    end

    it 'calculates subtotal and total' do
      get "/cart/#{session_id}"

      body = JSON.parse(last_response.body)
      expect(body['subtotal_cents']).to eq(300_000)
      expect(body['total_cents']).to eq(300_000 + 500_000 + 1_000_000)
    end
  end

  describe 'POST /cart/:session_id/items' do
    let(:valid_params) { { product_id: product_id, quantity: 2 } }

    context 'when product exists and has stock' do
      before do
        cart_repo = instance_double(Adapters::SequelCartRepository)
        product_repo = instance_double(Adapters::SequelProductRepository)

        allow(Adapters::SequelCartRepository).to receive(:new).and_return(cart_repo)
        allow(Adapters::SequelProductRepository).to receive(:new).and_return(product_repo)
        allow(product_repo).to receive(:find_by_id).with(product_id).and_return(product)
        allow(CartItem).to receive(:where).and_return(double(first: nil))
        allow(cart_repo).to receive(:add_item).and_return(cart_item)
      end

      it 'returns 201 status' do
        post "/cart/#{session_id}/items", valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
      end

      it 'returns added item' do
        post "/cart/#{session_id}/items", valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['product_id']).to eq(product_id)
        expect(body['quantity']).to eq(2)
      end
    end

    context 'when product is not found' do
      before do
        product_repo = instance_double(Adapters::SequelProductRepository)
        allow(Adapters::SequelProductRepository).to receive(:new).and_return(product_repo)
        allow(product_repo).to receive(:find_by_id).and_return(nil)
      end

      it 'returns 404 status' do
        post "/cart/#{session_id}/items", valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(404)
      end
    end

    context 'when stock is insufficient' do
      let(:low_stock_product) do
        instance_double('Product', id: product_id, stock: 1)
      end

      before do
        product_repo = instance_double(Adapters::SequelProductRepository)
        allow(Adapters::SequelProductRepository).to receive(:new).and_return(product_repo)
        allow(product_repo).to receive(:find_by_id).and_return(low_stock_product)
      end

      it 'returns 422 status' do
        post "/cart/#{session_id}/items", valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
      end
    end

    context 'when JSON is invalid' do
      it 'returns 400 status' do
        post "/cart/#{session_id}/items", 'invalid json', { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'PUT /cart/:session_id/items/:product_id' do
    let(:update_params) { { quantity: 5 } }

    context 'when updating quantity' do
      before do
        cart_repo = instance_double(Adapters::SequelCartRepository)
        product_repo = instance_double(Adapters::SequelProductRepository)

        allow(Adapters::SequelCartRepository).to receive(:new).and_return(cart_repo)
        allow(Adapters::SequelProductRepository).to receive(:new).and_return(product_repo)
        allow(product_repo).to receive(:find_by_id).and_return(product)
        allow(cart_repo).to receive(:update_quantity).and_return(
          instance_double('CartItem', id: 'item-uuid', product_id: product_id, quantity: 5)
        )
      end

      it 'returns 200 status' do
        put "/cart/#{session_id}/items/#{product_id}", update_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)
      end

      it 'returns updated item' do
        put "/cart/#{session_id}/items/#{product_id}", update_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['quantity']).to eq(5)
      end
    end

    context 'when quantity is 0' do
      before do
        cart_repo = instance_double(Adapters::SequelCartRepository)
        product_repo = instance_double(Adapters::SequelProductRepository)

        allow(Adapters::SequelCartRepository).to receive(:new).and_return(cart_repo)
        allow(Adapters::SequelProductRepository).to receive(:new).and_return(product_repo)
        allow(product_repo).to receive(:find_by_id).and_return(product)
        allow(cart_repo).to receive(:remove_item)
      end

      it 'removes the item' do
        put "/cart/#{session_id}/items/#{product_id}", { quantity: 0 }.to_json, { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['message']).to eq('Item removed from cart')
      end
    end
  end

  describe 'DELETE /cart/:session_id/items/:product_id' do
    before do
      cart_repo = instance_double(Adapters::SequelCartRepository)
      allow(Adapters::SequelCartRepository).to receive(:new).and_return(cart_repo)
      allow(cart_repo).to receive(:remove_item)
    end

    it 'returns 200 status' do
      delete "/cart/#{session_id}/items/#{product_id}"

      expect(last_response.status).to eq(200)
    end

    it 'returns success message' do
      delete "/cart/#{session_id}/items/#{product_id}"

      body = JSON.parse(last_response.body)
      expect(body['message']).to eq('Item removed from cart')
    end
  end

  describe 'DELETE /cart/:session_id' do
    before do
      cart_repo = instance_double(Adapters::SequelCartRepository)
      allow(Adapters::SequelCartRepository).to receive(:new).and_return(cart_repo)
      allow(cart_repo).to receive(:clear)
    end

    it 'returns 200 status' do
      delete "/cart/#{session_id}"

      expect(last_response.status).to eq(200)
    end

    it 'returns success message' do
      delete "/cart/#{session_id}"

      body = JSON.parse(last_response.body)
      expect(body['message']).to eq('Cart cleared')
    end
  end
end
