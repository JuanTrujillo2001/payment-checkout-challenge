require 'spec_helper'

RSpec.describe UseCases::FulfillTransaction do
  let(:transaction_repo) { instance_double(Adapters::SequelTransactionRepository) }
  let(:product_repo) { instance_double(Adapters::SequelProductRepository) }
  let(:cart_repo) { instance_double(Adapters::SequelCartRepository) }

  let(:use_case) do
    described_class.new(
      transaction_repo: transaction_repo,
      product_repo: product_repo,
      cart_repo: cart_repo
    )
  end

  let(:session_id) { 'session-uuid' }

  let(:transaction) do
    instance_double(
      'Transaction',
      id: 'transaction-uuid',
      status: 'APPROVED',
      :[] => nil
    )
  end

  let(:product) do
    instance_double('Product', id: 'product-uuid', stock: 10)
  end

  let(:transaction_item) do
    instance_double('TransactionItem', product_id: 'product-uuid', quantity: 2)
  end

  describe '#call' do
    context 'when transaction is approved and not fulfilled' do
      before do
        allow(transaction_repo).to receive(:find_by_id).with('transaction-uuid').and_return(transaction)
        allow(transaction).to receive(:[]).with(:fulfilled_at).and_return(nil)
        allow(transaction).to receive(:[]).with(:session_id).and_return(session_id)
        allow(TransactionItem).to receive(:where).and_return(double(all: [transaction_item]))
        allow(product_repo).to receive(:find_by_id).with('product-uuid').and_return(product)
        allow(product_repo).to receive(:update_stock)
        allow(cart_repo).to receive(:clear)
        allow(transaction_repo).to receive(:mark_fulfilled)
      end

      it 'returns Success' do
        result = use_case.call(transaction_id: 'transaction-uuid')

        expect(result).to be_success
      end

      it 'decrements product stock' do
        expect(product_repo).to receive(:update_stock).with('product-uuid', 8)

        use_case.call(transaction_id: 'transaction-uuid')
      end

      it 'clears the cart' do
        expect(cart_repo).to receive(:clear).with(session_id)

        use_case.call(transaction_id: 'transaction-uuid')
      end

      it 'marks transaction as fulfilled' do
        expect(transaction_repo).to receive(:mark_fulfilled).with('transaction-uuid')

        use_case.call(transaction_id: 'transaction-uuid')
      end
    end

    context 'when transaction is not found' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(nil)
      end

      it 'returns Failure with transaction_not_found error' do
        result = use_case.call(transaction_id: 'invalid-uuid')

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:transaction_not_found)
      end
    end

    context 'when transaction is already fulfilled' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(transaction)
        allow(transaction).to receive(:[]).with(:fulfilled_at).and_return(Time.now)
      end

      it 'returns Failure with already_fulfilled error' do
        result = use_case.call(transaction_id: 'transaction-uuid')

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:already_fulfilled)
      end
    end

    context 'when transaction is not approved' do
      let(:pending_transaction) do
        instance_double('Transaction', id: 'tx-uuid', status: 'PENDING', :[] => nil)
      end

      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(pending_transaction)
        allow(pending_transaction).to receive(:[]).with(:fulfilled_at).and_return(nil)
      end

      it 'returns Failure with not_approved error' do
        result = use_case.call(transaction_id: 'tx-uuid')

        expect(result).to be_failure
        expect(result.failure[:error]).to eq(:not_approved)
      end
    end

    context 'when transaction has no session_id' do
      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(transaction)
        allow(transaction).to receive(:[]).with(:fulfilled_at).and_return(nil)
        allow(transaction).to receive(:[]).with(:session_id).and_return(nil)
        allow(TransactionItem).to receive(:where).and_return(double(all: [transaction_item]))
        allow(product_repo).to receive(:find_by_id).with('product-uuid').and_return(product)
        allow(product_repo).to receive(:update_stock)
        allow(transaction_repo).to receive(:mark_fulfilled)
      end

      it 'skips cart clearing and still succeeds' do
        expect(cart_repo).not_to receive(:clear)

        result = use_case.call(transaction_id: 'transaction-uuid')
        expect(result).to be_success
      end
    end

    context 'with multiple transaction items' do
      let(:product2) { instance_double('Product', id: 'product-2', stock: 5) }
      let(:transaction_item2) { instance_double('TransactionItem', product_id: 'product-2', quantity: 3) }

      before do
        allow(transaction_repo).to receive(:find_by_id).and_return(transaction)
        allow(transaction).to receive(:[]).with(:fulfilled_at).and_return(nil)
        allow(transaction).to receive(:[]).with(:session_id).and_return(session_id)
        allow(TransactionItem).to receive(:where).and_return(double(all: [transaction_item, transaction_item2]))
        allow(product_repo).to receive(:find_by_id).with('product-uuid').and_return(product)
        allow(product_repo).to receive(:find_by_id).with('product-2').and_return(product2)
        allow(product_repo).to receive(:update_stock)
        allow(cart_repo).to receive(:clear)
        allow(transaction_repo).to receive(:mark_fulfilled)
      end

      it 'decrements stock for all products' do
        expect(product_repo).to receive(:update_stock).with('product-uuid', 8)
        expect(product_repo).to receive(:update_stock).with('product-2', 2)

        use_case.call(transaction_id: 'transaction-uuid')
      end
    end
  end
end
