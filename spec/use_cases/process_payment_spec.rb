require 'spec_helper'

RSpec.describe UseCases::ProcessPayment do
  let(:transaction_repo) { instance_double(Adapters::SequelTransactionRepository) }
  let(:payment_gateway) { instance_double(Adapters::WompiPaymentGateway) }

  let(:use_case) do
    described_class.new(
      transaction_repo: transaction_repo,
      payment_gateway: payment_gateway
    )
  end

  let(:transaction) do
    instance_double(
      'Transaction',
      id: 'transaction-uuid',
      reference: 'TX-2026-0001',
      status: 'PENDING',
      amount_cents: 150_000,
      base_fee_cents: 5000,
      delivery_fee_cents: 10_000,
      customer_id: 'customer-uuid',
      wompi_transaction_id: nil
    )
  end

  let(:updated_transaction) do
    instance_double(
      'Transaction',
      id: 'transaction-uuid',
      reference: 'TX-2026-0001',
      status: 'APPROVED',
      amount_cents: 150_000,
      base_fee_cents: 5000,
      delivery_fee_cents: 10_000,
      customer_id: 'customer-uuid',
      wompi_transaction_id: 'wompi-tx-123'
    )
  end

  let(:customer) do
    instance_double('Customer', id: 'customer-uuid', email: 'test@test.com')
  end

  let(:card_data) do
    {
      number: '4242424242424242',
      cvc: '123',
      exp_month: '12',
      exp_year: '29',
      card_holder: 'Juan Test'
    }
  end

  describe '#call' do
    context 'when payment is successful' do
      before do
        allow(transaction_repo).to receive(:find_by_id).with('transaction-uuid').and_return(transaction)
        allow(transaction_repo).to receive(:update_status).and_return(updated_transaction)
        allow(Customer).to receive(:[]).with('customer-uuid').and_return(customer)

        allow(payment_gateway).to receive(:get_acceptance_token).and_return(
          { success: true, data: { 'acceptance_token' => 'token-123' } }
        )
        allow(payment_gateway).to receive(:tokenize_card).and_return(
          { success: true, data: { 'id' => 'card-token-123' } }
        )
        allow(payment_gateway).to receive(:create_payment_source).and_return(
          { success: true, data: { 'id' => 'source-123' } }
        )
        allow(payment_gateway).to receive(:create_transaction).and_return(
          { success: true, data: { 'id' => 'wompi-tx-123', 'status' => 'APPROVED', 'finalized_at' => '2026-01-28T15:00:00Z' } }
        )
      end

      it 'returns Success with transaction data' do
        result = use_case.call(transaction_id: 'transaction-uuid', card_data: card_data)

        expect(result).to be_success
        expect(result.value![:transaction_id]).to eq('transaction-uuid')
        expect(result.value![:reference]).to eq('TX-2026-0001')
      end

      it 'calls payment gateway methods in correct order' do
        expect(payment_gateway).to receive(:get_acceptance_token).ordered
        expect(payment_gateway).to receive(:tokenize_card).with(card_data).ordered
        expect(payment_gateway).to receive(:create_payment_source).ordered
        expect(payment_gateway).to receive(:create_transaction).ordered

        use_case.call(transaction_id: 'transaction-uuid', card_data: card_data)
      end

      it 'updates transaction status with wompi_transaction_id' do
        expect(transaction_repo).to receive(:update_status).with(
          'transaction-uuid',
          'APPROVED',
          wompi_transaction_id: 'wompi-tx-123'
        )

        use_case.call(transaction_id: 'transaction-uuid', card_data: card_data)
      end
    end

    context 'when transaction is not found' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(nil)
      end

      it 'returns Failure with transaction_not_found error' do
        result = use_case.call(transaction_id: 'invalid-uuid', card_data: card_data)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:transaction_not_found)
      end
    end

    context 'when transaction is not pending' do
      let(:approved_transaction) do
        instance_double('Transaction', id: 'tx-uuid', status: 'APPROVED')
      end

      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(approved_transaction)
      end

      it 'returns Failure with invalid_status error' do
        result = use_case.call(transaction_id: 'tx-uuid', card_data: card_data)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:invalid_status)
      end
    end

    context 'when acceptance token fails' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(transaction)
        allow(payment_gateway).to receive(:get_acceptance_token).and_return(
          { success: false, error: 'Failed' }
        )
      end

      it 'returns Failure with acceptance_token_failed error' do
        result = use_case.call(transaction_id: 'transaction-uuid', card_data: card_data)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:acceptance_token_failed)
      end
    end

    context 'when card tokenization fails' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(transaction)
        allow(payment_gateway).to receive(:get_acceptance_token).and_return(
          { success: true, data: { 'acceptance_token' => 'token-123' } }
        )
        allow(payment_gateway).to receive(:tokenize_card).and_return(
          { success: false, error: { 'error' => { 'message' => 'Invalid card' } } }
        )
      end

      it 'returns Failure with tokenization_failed error' do
        result = use_case.call(transaction_id: 'transaction-uuid', card_data: card_data)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:tokenization_failed)
      end
    end

    context 'when payment source creation fails' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(transaction)
        allow(Customer).to receive(:[]).and_return(customer)
        allow(payment_gateway).to receive(:get_acceptance_token).and_return(
          { success: true, data: { 'acceptance_token' => 'token-123' } }
        )
        allow(payment_gateway).to receive(:tokenize_card).and_return(
          { success: true, data: { 'id' => 'card-token-123' } }
        )
        allow(payment_gateway).to receive(:create_payment_source).and_return(
          { success: false, error: { 'error' => { 'message' => 'Invalid token' } } }
        )
      end

      it 'returns Failure with payment_source_failed error' do
        result = use_case.call(transaction_id: 'transaction-uuid', card_data: card_data)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:payment_source_failed)
      end
    end

    context 'when wompi transaction creation fails' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(transaction)
        allow(Customer).to receive(:[]).and_return(customer)
        allow(payment_gateway).to receive(:get_acceptance_token).and_return(
          { success: true, data: { 'acceptance_token' => 'token-123' } }
        )
        allow(payment_gateway).to receive(:tokenize_card).and_return(
          { success: true, data: { 'id' => 'card-token-123' } }
        )
        allow(payment_gateway).to receive(:create_payment_source).and_return(
          { success: true, data: { 'id' => 'source-123' } }
        )
        allow(payment_gateway).to receive(:create_transaction).and_return(
          { success: false, error: { 'error' => { 'message' => 'Transaction failed' } } }
        )
      end

      it 'returns Failure with wompi_transaction_failed error' do
        result = use_case.call(transaction_id: 'transaction-uuid', card_data: card_data)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:wompi_transaction_failed)
      end
    end

    context 'with custom installments' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(transaction)
        allow(transaction_repo).to receive(:update_status).and_return(updated_transaction)
        allow(Customer).to receive(:[]).and_return(customer)
        allow(payment_gateway).to receive(:get_acceptance_token).and_return(
          { success: true, data: { 'acceptance_token' => 'token-123' } }
        )
        allow(payment_gateway).to receive(:tokenize_card).and_return(
          { success: true, data: { 'id' => 'card-token-123' } }
        )
        allow(payment_gateway).to receive(:create_payment_source).and_return(
          { success: true, data: { 'id' => 'source-123' } }
        )
        allow(payment_gateway).to receive(:create_transaction).and_return(
          { success: true, data: { 'id' => 'wompi-tx-123', 'status' => 'APPROVED', 'finalized_at' => nil } }
        )
      end

      it 'passes installments to create_transaction' do
        expect(payment_gateway).to receive(:create_transaction).with(
          hash_including(installments: 3)
        )

        use_case.call(transaction_id: 'transaction-uuid', card_data: card_data, installments: 3)
      end
    end
  end
end
