require 'spec_helper'

RSpec.describe UseCases::CreateTransactionFromCart do
  let(:cart_repo) { instance_double(Adapters::SequelCartRepository) }
  let(:product_repo) { instance_double(Adapters::SequelProductRepository) }
  let(:customer_repo) { instance_double(Adapters::SequelCustomerRepository) }
  let(:delivery_repo) { instance_double(Adapters::SequelDeliveryRepository) }
  let(:transaction_repo) { instance_double(Adapters::SequelTransactionRepository) }

  let(:use_case) do
    described_class.new(
      cart_repo: cart_repo,
      product_repo: product_repo,
      customer_repo: customer_repo,
      delivery_repo: delivery_repo,
      transaction_repo: transaction_repo
    )
  end

  let(:session_id) { 'session-uuid' }

  let(:product1) do
    instance_double('Product', id: 'product-1', name: 'Product 1', price_cents: 150_000, stock: 10)
  end

  let(:product2) do
    instance_double('Product', id: 'product-2', name: 'Product 2', price_cents: 200_000, stock: 5)
  end

  let(:cart_item1) do
    instance_double('CartItem', id: 'item-1', product_id: 'product-1', quantity: 2)
  end

  let(:cart_item2) do
    instance_double('CartItem', id: 'item-2', product_id: 'product-2', quantity: 1)
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
      amount_cents: 500_000,
      base_fee_cents: 500_000,
      delivery_fee_cents: 1_000_000
    )
  end

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

  describe '#call' do
    context 'when cart has items and all validations pass' do
      before do
        allow(cart_repo).to receive(:get_items).with(session_id).and_return([cart_item1, cart_item2])
        allow(product_repo).to receive(:find_by_id).with('product-1').and_return(product1)
        allow(product_repo).to receive(:find_by_id).with('product-2').and_return(product2)
        allow(customer_repo).to receive(:create).and_return(customer)
        allow(delivery_repo).to receive(:create).and_return(delivery)
        allow(transaction_repo).to receive(:next_reference_number).and_return('TX-2026-0001')
        allow(transaction_repo).to receive(:create).and_return(transaction)
        allow(TransactionItem).to receive(:create)
      end

      it 'returns Success with transaction data' do
        result = use_case.call(valid_params)

        expect(result).to be_success
        expect(result.value![:transaction_id]).to eq('transaction-uuid')
        expect(result.value![:reference]).to eq('TX-2026-0001')
        expect(result.value![:status]).to eq('pending')
      end

      it 'includes items detail in response' do
        result = use_case.call(valid_params)

        expect(result.value![:items].length).to eq(2)
        expect(result.value![:items].first[:product_name]).to eq('Product 1')
      end

      it 'calculates total correctly' do
        result = use_case.call(valid_params)

        # amount: 500_000, base_fee: 500_000, delivery: 1_000_000
        expect(result.value![:total_cents]).to eq(2_000_000)
      end

      it 'creates transaction items for each cart item' do
        expect(TransactionItem).to receive(:create).twice

        use_case.call(valid_params)
      end

      it 'does NOT clear cart (deferred to fulfillment)' do
        expect(cart_repo).not_to receive(:clear)

        use_case.call(valid_params)
      end

      it 'does NOT decrement stock (deferred to fulfillment)' do
        expect(product_repo).not_to receive(:update_stock)

        use_case.call(valid_params)
      end
    end

    context 'when cart is empty' do
      before do
        allow(cart_repo).to receive(:get_items).with(session_id).and_return([])
      end

      it 'returns Failure with empty_cart error' do
        result = use_case.call(valid_params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:empty_cart)
      end
    end

    context 'when product has insufficient stock' do
      let(:low_stock_product) do
        instance_double('Product', id: 'product-1', name: 'Product 1', price_cents: 150_000, stock: 1)
      end

      before do
        allow(cart_repo).to receive(:get_items).with(session_id).and_return([cart_item1])
        allow(product_repo).to receive(:find_by_id).with('product-1').and_return(low_stock_product)
      end

      it 'returns Failure with insufficient_stock error' do
        result = use_case.call(valid_params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:insufficient_stock)
      end
    end

    context 'when product is not found' do
      before do
        allow(cart_repo).to receive(:get_items).with(session_id).and_return([cart_item1])
        allow(product_repo).to receive(:find_by_id).with('product-1').and_return(nil)
      end

      it 'returns Failure with insufficient_stock error' do
        result = use_case.call(valid_params)

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:insufficient_stock)
      end
    end

    context 'when customer creation fails' do
      before do
        allow(cart_repo).to receive(:get_items).with(session_id).and_return([cart_item1])
        allow(product_repo).to receive(:find_by_id).with('product-1').and_return(product1)
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
        allow(cart_repo).to receive(:get_items).with(session_id).and_return([cart_item1])
        allow(product_repo).to receive(:find_by_id).with('product-1').and_return(product1)
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
        allow(cart_repo).to receive(:get_items).with(session_id).and_return([cart_item1])
        allow(product_repo).to receive(:find_by_id).with('product-1').and_return(product1)
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
  end
end
