require 'spec_helper'

RSpec.describe 'Transactions Controller' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe 'POST /transactions' do
    let(:valid_params) do
      {
        product_id: 'product-uuid',
        quantity: 1,
        customer: {
          full_name: 'Juan Test',
          identity_document: 12345678,
          email: 'juan@test.com',
          phone: '3001234567'
        },
        delivery: {
          address: 'Calle 123',
          city: 'Bogotá',
          country: 'Colombia'
        }
      }
    end

    context 'when request is successful' do
      let(:success_result) do
        Dry::Monads::Success({
          transaction_id: 'tx-uuid',
          reference: 'TX-2026-0001',
          status: 'pending',
          amount_cents: 150_000,
          base_fee_cents: 5000,
          delivery_fee_cents: 10_000,
          total_cents: 165_000
        })
      end

      before do
        use_case = instance_double(UseCases::CreateTransaction)
        allow(UseCases::CreateTransaction).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(success_result)
      end

      it 'returns 201 status' do
        post '/transactions', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
      end

      it 'returns transaction data' do
        post '/transactions', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['transaction_id']).to eq('tx-uuid')
        expect(body['reference']).to eq('TX-2026-0001')
      end
    end

    context 'when product is not found' do
      let(:failure_result) do
        Dry::Monads::Failure({ error: :product_not_found, message: 'Product not found' })
      end

      before do
        use_case = instance_double(UseCases::CreateTransaction)
        allow(UseCases::CreateTransaction).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(failure_result)
      end

      it 'returns 404 status' do
        post '/transactions', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(404)
      end

      it 'returns error message' do
        post '/transactions', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('product_not_found')
      end
    end

    context 'when stock is insufficient' do
      let(:failure_result) do
        Dry::Monads::Failure({ error: :insufficient_stock, message: 'Insufficient stock' })
      end

      before do
        use_case = instance_double(UseCases::CreateTransaction)
        allow(UseCases::CreateTransaction).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(failure_result)
      end

      it 'returns 422 status' do
        post '/transactions', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
      end
    end

    context 'when JSON is invalid' do
      it 'returns 400 status' do
        post '/transactions', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
      end

      it 'returns error message' do
        post '/transactions', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('invalid_json')
      end
    end
  end

  describe 'POST /transactions/from-cart' do
    let(:session_id) { SecureRandom.uuid }

    let(:valid_params) do
      {
        session_id: session_id,
        customer: {
          full_name: 'Juan Test',
          identity_document: 12345678,
          email: 'juan@test.com',
          phone: '3001234567'
        },
        delivery: {
          address: 'Calle 123',
          city: 'Bogotá',
          country: 'Colombia'
        }
      }
    end

    context 'when request is successful' do
      let(:success_result) do
        Dry::Monads::Success({
          transaction_id: 'tx-uuid',
          reference: 'TX-2026-0001',
          status: 'pending',
          items: [
            { product_id: 'prod-1', product_name: 'Product 1', quantity: 2, price_cents: 150_000, subtotal_cents: 300_000 }
          ],
          amount_cents: 300_000,
          base_fee_cents: 500_000,
          delivery_fee_cents: 1_000_000,
          total_cents: 1_800_000
        })
      end

      before do
        use_case = instance_double(UseCases::CreateTransactionFromCart)
        allow(UseCases::CreateTransactionFromCart).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(success_result)
      end

      it 'returns 201 status' do
        post '/transactions/from-cart', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
      end

      it 'returns transaction data with items' do
        post '/transactions/from-cart', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['transaction_id']).to eq('tx-uuid')
        expect(body['reference']).to eq('TX-2026-0001')
        expect(body['items'].length).to eq(1)
      end
    end

    context 'when cart is empty' do
      let(:failure_result) do
        Dry::Monads::Failure({ error: :empty_cart, message: 'Cart is empty' })
      end

      before do
        use_case = instance_double(UseCases::CreateTransactionFromCart)
        allow(UseCases::CreateTransactionFromCart).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(failure_result)
      end

      it 'returns 422 status' do
        post '/transactions/from-cart', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
      end

      it 'returns error message' do
        post '/transactions/from-cart', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('empty_cart')
      end
    end

    context 'when stock is insufficient' do
      let(:failure_result) do
        Dry::Monads::Failure({ error: :insufficient_stock, message: 'Insufficient stock', product_id: 'prod-1' })
      end

      before do
        use_case = instance_double(UseCases::CreateTransactionFromCart)
        allow(UseCases::CreateTransactionFromCart).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(failure_result)
      end

      it 'returns 422 status' do
        post '/transactions/from-cart', valid_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
      end
    end

    context 'when JSON is invalid' do
      it 'returns 400 status' do
        post '/transactions/from-cart', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'GET /transactions/:id' do
    context 'when transaction exists' do
      let(:transaction) do
        instance_double(
          'Transaction',
          id: 'tx-uuid',
          reference: 'TX-2026-0001',
          status: 'PENDING',
          amount_cents: 150_000,
          base_fee_cents: 5000,
          delivery_fee_cents: 10_000,
          wompi_transaction_id: nil
        )
      end

      before do
        repo = instance_double(Adapters::SequelTransactionRepository)
        allow(Adapters::SequelTransactionRepository).to receive(:new).and_return(repo)
        allow(repo).to receive(:find_by_id).with('tx-uuid').and_return(transaction)
      end

      it 'returns 200 status' do
        get '/transactions/tx-uuid'

        expect(last_response.status).to eq(200)
      end

      it 'returns transaction data' do
        get '/transactions/tx-uuid'

        body = JSON.parse(last_response.body)
        expect(body['transaction_id']).to eq('tx-uuid')
        expect(body['status']).to eq('pending')
        expect(body['total_cents']).to eq(165_000)
      end
    end

    context 'when transaction does not exist' do
      before do
        repo = instance_double(Adapters::SequelTransactionRepository)
        allow(Adapters::SequelTransactionRepository).to receive(:new).and_return(repo)
        allow(repo).to receive(:find_by_id).and_return(nil)
      end

      it 'returns 404 status' do
        get '/transactions/invalid-uuid'

        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'POST /transactions/:id/pay' do
    let(:card_params) do
      {
        card: {
          number: '4242424242424242',
          cvc: '123',
          exp_month: '12',
          exp_year: '29',
          card_holder: 'Juan Test'
        },
        installments: 1
      }
    end

    context 'when payment is successful' do
      let(:success_result) do
        Dry::Monads::Success({
          transaction_id: 'tx-uuid',
          reference: 'TX-2026-0001',
          status: 'approved',
          wompi_transaction_id: 'wompi-123',
          amount_cents: 150_000,
          total_cents: 165_000,
          wompi_status: 'APPROVED',
          finalized_at: '2026-01-28T15:00:00Z'
        })
      end

      before do
        use_case = instance_double(UseCases::ProcessPayment)
        allow(UseCases::ProcessPayment).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(success_result)
      end

      it 'returns 200 status' do
        post '/transactions/tx-uuid/pay', card_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)
      end

      it 'returns payment result' do
        post '/transactions/tx-uuid/pay', card_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        body = JSON.parse(last_response.body)
        expect(body['wompi_transaction_id']).to eq('wompi-123')
        expect(body['wompi_status']).to eq('APPROVED')
      end
    end

    context 'when transaction is not found' do
      let(:failure_result) do
        Dry::Monads::Failure({ error: :transaction_not_found, message: 'Transaction not found' })
      end

      before do
        use_case = instance_double(UseCases::ProcessPayment)
        allow(UseCases::ProcessPayment).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(failure_result)
      end

      it 'returns 404 status' do
        post '/transactions/invalid-uuid/pay', card_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(404)
      end
    end

    context 'when transaction is not pending' do
      let(:failure_result) do
        Dry::Monads::Failure({ error: :invalid_status, message: 'Transaction is not pending' })
      end

      before do
        use_case = instance_double(UseCases::ProcessPayment)
        allow(UseCases::ProcessPayment).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(failure_result)
      end

      it 'returns 422 status' do
        post '/transactions/tx-uuid/pay', card_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
      end
    end

    context 'when tokenization fails' do
      let(:failure_result) do
        Dry::Monads::Failure({ error: :tokenization_failed, message: 'Invalid card' })
      end

      before do
        use_case = instance_double(UseCases::ProcessPayment)
        allow(UseCases::ProcessPayment).to receive(:new).and_return(use_case)
        allow(use_case).to receive(:call).and_return(failure_result)
      end

      it 'returns 400 status' do
        post '/transactions/tx-uuid/pay', card_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'GET /transactions/:id/status' do
    context 'when transaction exists and has wompi_transaction_id' do
      let(:transaction) do
        instance_double(
          'Transaction',
          id: 'tx-uuid',
          reference: 'TX-2026-0001',
          status: 'PENDING',
          wompi_transaction_id: 'wompi-123',
          :[] => nil
        )
      end

      let(:wompi_response) do
        {
          success: true,
          data: {
            'id' => 'wompi-123',
            'status' => 'APPROVED',
            'payment_method_type' => 'CARD',
            'finalized_at' => '2026-01-28T15:00:00Z',
            'status_message' => nil
          }
        }
      end

      before do
        repo = instance_double(Adapters::SequelTransactionRepository)
        allow(Adapters::SequelTransactionRepository).to receive(:new).and_return(repo)
        allow(repo).to receive(:find_by_id).with('tx-uuid').and_return(transaction)
        allow(repo).to receive(:update_status)
        allow(transaction).to receive(:[]).with(:fulfilled_at).and_return(nil)

        gateway = instance_double(Adapters::WompiPaymentGateway)
        allow(Adapters::WompiPaymentGateway).to receive(:new).and_return(gateway)
        allow(gateway).to receive(:get_transaction).with('wompi-123').and_return(wompi_response)

        # Mock FulfillTransaction para cuando el status cambie a APPROVED
        fulfill_use_case = instance_double(UseCases::FulfillTransaction)
        allow(UseCases::FulfillTransaction).to receive(:new).and_return(fulfill_use_case)
        allow(fulfill_use_case).to receive(:call).and_return(Dry::Monads::Success(transaction))
      end

      it 'returns 200 status' do
        get '/transactions/tx-uuid/status'

        expect(last_response.status).to eq(200)
      end

      it 'returns updated status from Wompi' do
        get '/transactions/tx-uuid/status'

        body = JSON.parse(last_response.body)
        expect(body['wompi_status']).to eq('APPROVED')
        expect(body['status']).to eq('approved')
      end
    end

    context 'when transaction has no wompi_transaction_id' do
      let(:transaction) do
        instance_double(
          'Transaction',
          id: 'tx-uuid',
          wompi_transaction_id: nil
        )
      end

      before do
        repo = instance_double(Adapters::SequelTransactionRepository)
        allow(Adapters::SequelTransactionRepository).to receive(:new).and_return(repo)
        allow(repo).to receive(:find_by_id).and_return(transaction)
      end

      it 'returns 422 status' do
        get '/transactions/tx-uuid/status'

        expect(last_response.status).to eq(422)
      end

      it 'returns not_processed error' do
        get '/transactions/tx-uuid/status'

        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('not_processed')
      end
    end

    context 'when transaction does not exist' do
      before do
        repo = instance_double(Adapters::SequelTransactionRepository)
        allow(Adapters::SequelTransactionRepository).to receive(:new).and_return(repo)
        allow(repo).to receive(:find_by_id).and_return(nil)
      end

      it 'returns 404 status' do
        get '/transactions/invalid-uuid/status'

        expect(last_response.status).to eq(404)
      end
    end
  end
end
