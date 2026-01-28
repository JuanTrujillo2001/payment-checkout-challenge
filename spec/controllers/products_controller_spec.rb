require 'spec_helper'

RSpec.describe 'Products Controller' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe 'GET /products' do
    let(:products) do
      [
        instance_double('Product', id: 'prod-1', name: 'Product 1', description: 'Desc 1', price_cents: 100_000, stock: 10),
        instance_double('Product', id: 'prod-2', name: 'Product 2', description: 'Desc 2', price_cents: 200_000, stock: 5)
      ]
    end

    before do
      allow(Product).to receive(:all).and_return(products)
    end

    it 'returns 200 status' do
      get '/products'

      expect(last_response.status).to eq(200)
    end

    it 'returns all products' do
      get '/products'

      body = JSON.parse(last_response.body)
      expect(body.length).to eq(2)
      expect(body[0]['name']).to eq('Product 1')
      expect(body[1]['name']).to eq('Product 2')
    end

    it 'returns product attributes' do
      get '/products'

      body = JSON.parse(last_response.body)
      expect(body[0]).to include('id', 'name', 'description', 'price_cents', 'stock')
    end
  end

  describe 'GET /health' do
    it 'returns 200 status' do
      get '/health'

      expect(last_response.status).to eq(200)
    end

    it 'returns ok status' do
      get '/health'

      body = JSON.parse(last_response.body)
      expect(body['status']).to eq('ok')
    end
  end
end
