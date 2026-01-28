require 'spec_helper'

RSpec.describe Adapters::WompiPaymentGateway do
  let(:gateway) { described_class.new }
  let(:base_url) { ENV['WOMPI_BASE_URL'] || 'https://sandbox.wompi.co/v1' }
  let(:public_key) { ENV['WOMPI_PUBLIC_KEY'] }
  let(:private_key) { ENV['WOMPI_PRIVATE_KEY'] }

  describe '#tokenize_card' do
    let(:card_data) do
      {
        number: '4242424242424242',
        cvc: '123',
        exp_month: '12',
        exp_year: '29',
        card_holder: 'Juan Test'
      }
    end

    context 'when tokenization is successful' do
      before do
        stub_request(:post, "#{base_url}/tokens/cards")
          .with(
            headers: { 'Authorization' => "Bearer #{public_key}" }
          )
          .to_return(
            status: 200,
            body: { data: { id: 'tok_test_123', brand: 'VISA', last_four: '4242' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success with token data' do
        result = gateway.tokenize_card(card_data)

        expect(result[:success]).to be true
        expect(result[:data]['id']).to eq('tok_test_123')
        expect(result[:data]['brand']).to eq('VISA')
      end
    end

    context 'when tokenization fails' do
      before do
        stub_request(:post, "#{base_url}/tokens/cards")
          .to_return(
            status: 422,
            body: { error: { type: 'INPUT_VALIDATION_ERROR', message: 'Invalid card number' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns failure with error' do
        result = gateway.tokenize_card(card_data)

        expect(result[:success]).to be false
        expect(result[:status]).to eq(422)
      end
    end
  end

  describe '#get_acceptance_token' do
    context 'when successful' do
      before do
        stub_request(:get, "#{base_url}/merchants/#{public_key}")
          .to_return(
            status: 200,
            body: {
              data: {
                presigned_acceptance: {
                  acceptance_token: 'acceptance_token_123',
                  permalink: 'https://wompi.com/terms',
                  type: 'END_USER_POLICY'
                }
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns acceptance token data' do
        result = gateway.get_acceptance_token

        expect(result[:success]).to be true
        expect(result[:data]['acceptance_token']).to eq('acceptance_token_123')
      end
    end

    context 'when merchant not found' do
      before do
        stub_request(:get, "#{base_url}/merchants/#{public_key}")
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'returns failure' do
        result = gateway.get_acceptance_token

        expect(result[:success]).to be false
      end
    end
  end

  describe '#create_payment_source' do
    let(:params) do
      {
        token: 'tok_test_123',
        customer_email: 'test@test.com',
        acceptance_token: 'acceptance_token_123'
      }
    end

    context 'when successful' do
      before do
        stub_request(:post, "#{base_url}/payment_sources")
          .with(headers: { 'Authorization' => "Bearer #{private_key}" })
          .to_return(
            status: 201,
            body: { data: { id: 12345, type: 'CARD', status: 'AVAILABLE' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns payment source data' do
        result = gateway.create_payment_source(**params)

        expect(result[:success]).to be true
        expect(result[:data]['id']).to eq(12345)
        expect(result[:data]['type']).to eq('CARD')
      end
    end

    context 'when token is invalid' do
      before do
        stub_request(:post, "#{base_url}/payment_sources")
          .to_return(
            status: 422,
            body: { error: { message: 'Invalid token' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns failure' do
        result = gateway.create_payment_source(**params)

        expect(result[:success]).to be false
      end
    end
  end

  describe '#create_transaction' do
    let(:params) do
      {
        amount_cents: 165000,
        currency: 'COP',
        payment_source_id: 12345,
        reference: 'TX-2026-0001',
        customer_email: 'test@test.com',
        installments: 1
      }
    end

    context 'when transaction is approved' do
      before do
        stub_request(:post, "#{base_url}/transactions")
          .with(headers: { 'Authorization' => "Bearer #{private_key}" })
          .to_return(
            status: 201,
            body: {
              data: {
                id: 'wompi-tx-123',
                status: 'APPROVED',
                reference: 'TX-2026-0001',
                amount_in_cents: 165000,
                finalized_at: '2026-01-28T15:00:00Z'
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns approved transaction' do
        result = gateway.create_transaction(**params)

        expect(result[:success]).to be true
        expect(result[:data]['id']).to eq('wompi-tx-123')
        expect(result[:data]['status']).to eq('APPROVED')
      end
    end

    context 'when transaction is declined' do
      before do
        stub_request(:post, "#{base_url}/transactions")
          .to_return(
            status: 201,
            body: {
              data: {
                id: 'wompi-tx-456',
                status: 'DECLINED',
                status_message: 'Insufficient funds'
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns declined transaction' do
        result = gateway.create_transaction(**params)

        expect(result[:success]).to be true
        expect(result[:data]['status']).to eq('DECLINED')
      end
    end

    context 'when transaction is pending' do
      before do
        stub_request(:post, "#{base_url}/transactions")
          .to_return(
            status: 201,
            body: { data: { id: 'wompi-tx-789', status: 'PENDING' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns pending transaction' do
        result = gateway.create_transaction(**params)

        expect(result[:success]).to be true
        expect(result[:data]['status']).to eq('PENDING')
      end
    end

    context 'when request fails' do
      before do
        stub_request(:post, "#{base_url}/transactions")
          .to_return(status: 500, body: { error: 'Internal error' }.to_json)
      end

      it 'returns failure' do
        result = gateway.create_transaction(**params)

        expect(result[:success]).to be false
      end
    end
  end

  describe '#get_transaction' do
    let(:transaction_id) { 'wompi-tx-123' }

    context 'when transaction exists' do
      before do
        stub_request(:get, "#{base_url}/transactions/#{transaction_id}")
          .to_return(
            status: 200,
            body: {
              data: {
                id: transaction_id,
                status: 'APPROVED',
                reference: 'TX-2026-0001',
                finalized_at: '2026-01-28T15:00:00Z'
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns transaction data' do
        result = gateway.get_transaction(transaction_id)

        expect(result[:success]).to be true
        expect(result[:data]['id']).to eq(transaction_id)
        expect(result[:data]['status']).to eq('APPROVED')
      end
    end

    context 'when transaction not found' do
      before do
        stub_request(:get, "#{base_url}/transactions/#{transaction_id}")
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'returns failure' do
        result = gateway.get_transaction(transaction_id)

        expect(result[:success]).to be false
      end
    end
  end
end
