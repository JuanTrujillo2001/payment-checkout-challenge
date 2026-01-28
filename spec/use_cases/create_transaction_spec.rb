require 'spec_helper'

RSpec.describe UseCases::CreateTransaction do
  let(:product_repo) { instance_double(Adapters::SequelProductRepository) }
  let(:customer_repo) { instance_double(Adapters::SequelCustomerRepository) }
  let(:delivery_repo) { instance_double(Adapters::SequelDeliveryRepository) }
  let(:transaction_repo) { instance_double(Adapters::SequelTransactionRepository) }

  let(:use_case) do
    described_class.new(
      product_repo: product_repo,
      customer_repo: customer_repo,
      delivery_repo: delivery_repo,
      transaction_repo: transaction_repo
    )
  end

  let(:product) do
    instance_double('Product', id: 'product-uuid', price_cents: 150_000, stock: 10)
  end

  let(:customer) do
    instance_double('Customer', id: 'customer-uuid')
  end

  let(:delivery) do
    instance_double('Delivery', id: 'delivery-uuid')
  end

  let(:transaction) do
    instance_double(
      'Transaction',
      id: 'transaction-uuid',
      reference: 'TX-2026-0001',
      status: 'PENDING',
      amount_cents: 150_000,
      base_fee_cents: 5000,
      delivery_fee_cents: 10_000
    )
  end

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

  describe '#call' do
    context 'when all validations pass' do
      before do
        allow(product_repo).to receive(:find_by_id).with('product-uuid').and_return(product)
        allow(product_repo).to receive(:update_stock)
        allow(customer_repo).to receive(:create).and_return(customer)
        allow(delivery_repo).to receive(:create).and_return(delivery)
        allow(transaction_repo).to receive(:next_reference_number).and_return('TX-2026-0001')
        allow(transaction_repo).to receive(:create).and_return(transaction)
      end

      it 'returns Success with transaction data' do
        result = use_case.call(valid_params)

        expect(result).to be_success
        expect(result.value![:transaction_id]).to eq('transaction-uuid')
        expect(result.value![:reference]).to eq('TX-2026-0001')
        expect(result.value![:status]).to eq('pending')
      end

      it 'creates customer with correct attributes' do
        expect(customer_repo).to receive(:create).with(
          full_name: 'Juan Test',
          identity_document: 12345678,
          email: 'juan@test.com',
          phone: '3001234567'
        )

        use_case.call(valid_params)
      end

      it 'creates delivery with customer_id' do
        expect(delivery_repo).to receive(:create).with(
          customer_id: 'customer-uuid',
          address: 'Calle 123',
          city: 'Bogotá',
          country: 'Colombia'
        )

        use_case.call(valid_params)
      end

      it 'creates transaction with correct amounts' do
        expect(transaction_repo).to receive(:create).with(
          hash_including(
            reference: 'TX-2026-0001',
            status: 'PENDING',
            amount_cents: 150_000,
            base_fee_cents: 5000,
            delivery_fee_cents: 10_000,
            product_id: 'product-uuid',
            customer_id: 'customer-uuid',
            delivery_id: 'delivery-uuid'
          )
        )

        use_case.call(valid_params)
      end

      it 'decrements product stock' do
        expect(product_repo).to receive(:update_stock).with('product-uuid', 9)

        use_case.call(valid_params)
      end

      it 'calculates total_cents correctly' do
        result = use_case.call(valid_params)

        expect(result.value![:total_cents]).to eq(165_000)
      end
    end

    context 'when product is not found' do
      before do
        allow(product_repo).to receive(:find_by_id).and_return(nil)
      end

      it 'returns Failure with product_not_found error' do
        result = use_case.call(valid_params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:product_not_found)
      end
    end

    context 'when stock is insufficient' do
      let(:low_stock_product) do
        instance_double('Product', id: 'product-uuid', price_cents: 150_000, stock: 0)
      end

      before do
        allow(product_repo).to receive(:find_by_id).and_return(low_stock_product)
      end

      it 'returns Failure with insufficient_stock error' do
        result = use_case.call(valid_params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:insufficient_stock)
      end
    end

    context 'when quantity exceeds stock' do
      before do
        allow(product_repo).to receive(:find_by_id).and_return(product)
      end

      it 'returns Failure with insufficient_stock error' do
        params = valid_params.merge(quantity: 100)
        result = use_case.call(params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:insufficient_stock)
      end
    end

    context 'when quantity is greater than 1' do
      before do
        allow(product_repo).to receive(:find_by_id).and_return(product)
        allow(product_repo).to receive(:update_stock)
        allow(customer_repo).to receive(:create).and_return(customer)
        allow(delivery_repo).to receive(:create).and_return(delivery)
        allow(transaction_repo).to receive(:next_reference_number).and_return('TX-2026-0001')
        allow(transaction_repo).to receive(:create).and_return(transaction)
      end

      it 'calculates amount based on quantity' do
        expect(transaction_repo).to receive(:create).with(
          hash_including(amount_cents: 300_000)
        )

        use_case.call(valid_params.merge(quantity: 2))
      end

      it 'decrements stock by quantity' do
        expect(product_repo).to receive(:update_stock).with('product-uuid', 8)

        use_case.call(valid_params.merge(quantity: 2))
      end
    end

    context 'when customer creation fails' do
      before do
        allow(product_repo).to receive(:find_by_id).and_return(product)
        allow(customer_repo).to receive(:create).and_raise(Sequel::Error.new('DB error'))
      end

      it 'returns Failure with customer_creation_failed error' do
        result = use_case.call(valid_params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:customer_creation_failed)
      end
    end

    context 'when delivery creation fails' do
      before do
        allow(product_repo).to receive(:find_by_id).and_return(product)
        allow(customer_repo).to receive(:create).and_return(customer)
        allow(delivery_repo).to receive(:create).and_raise(Sequel::Error.new('DB error'))
      end

      it 'returns Failure with delivery_creation_failed error' do
        result = use_case.call(valid_params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:delivery_creation_failed)
      end
    end

    context 'when transaction creation fails' do
      before do
        allow(product_repo).to receive(:find_by_id).and_return(product)
        allow(customer_repo).to receive(:create).and_return(customer)
        allow(delivery_repo).to receive(:create).and_return(delivery)
        allow(transaction_repo).to receive(:next_reference_number).and_return('TX-2026-0001')
        allow(transaction_repo).to receive(:create).and_raise(Sequel::Error.new('DB error'))
      end

      it 'returns Failure with transaction_creation_failed error' do
        result = use_case.call(valid_params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:transaction_creation_failed)
      end
    end

    context 'with default quantity' do
      before do
        allow(product_repo).to receive(:find_by_id).and_return(product)
        allow(product_repo).to receive(:update_stock)
        allow(customer_repo).to receive(:create).and_return(customer)
        allow(delivery_repo).to receive(:create).and_return(delivery)
        allow(transaction_repo).to receive(:next_reference_number).and_return('TX-2026-0001')
        allow(transaction_repo).to receive(:create).and_return(transaction)
      end

      it 'uses quantity 1 when not provided' do
        params = valid_params.tap { |p| p.delete(:quantity) }

        expect(product_repo).to receive(:update_stock).with('product-uuid', 9)

        use_case.call(params)
      end
    end
  end
end
