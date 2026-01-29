require 'spec_helper'

RSpec.describe Adapters::SequelTransactionRepository do
  let(:repo) { described_class.new }

  describe '#create' do
    let(:product) { Product.create(name: 'Test Product', description: 'Test', price_cents: 100_000, stock: 10) }
    let(:customer) { Customer.create(full_name: 'Test User', identity_document: 12345678, email: 'test@test.com') }
    let(:delivery) { Delivery.create(customer_id: customer.id, address: 'Test', city: 'Test', country: 'CO') }

    let(:attributes) do
      {
        reference: 'TX-TEST-0001',
        status: 'PENDING',
        amount_cents: 100_000,
        base_fee_cents: 5000,
        delivery_fee_cents: 10_000,
        product_id: product.id,
        customer_id: customer.id,
        delivery_id: delivery.id
      }
    end

    after do
      Transaction.where(reference: 'TX-TEST-0001').delete
      Delivery.where(id: delivery.id).delete
      Customer.where(id: customer.id).delete
      Product.where(id: product.id).delete
    end

    it 'creates a transaction with given attributes' do
      transaction = repo.create(attributes)

      expect(transaction.reference).to eq('TX-TEST-0001')
      expect(transaction.status).to eq('PENDING')
      expect(transaction.amount_cents).to eq(100_000)
    end

    it 'generates a UUID for id' do
      transaction = repo.create(attributes)

      expect(transaction.id).to match(/^[0-9a-f-]{36}$/)
    end
  end

  describe '#find_by_id' do
    context 'when transaction exists' do
      let(:product) { Product.create(name: 'Test Product', description: 'Test', price_cents: 100_000, stock: 10) }
      let(:customer) { Customer.create(full_name: 'Test User', identity_document: 12345678, email: 'test@test.com') }
      let(:delivery) { Delivery.create(customer_id: customer.id, address: 'Test', city: 'Test', country: 'CO') }
      let!(:transaction) do
        Transaction.create(
          reference: 'TX-FIND-0001',
          status: 'PENDING',
          amount_cents: 100_000,
          base_fee_cents: 5000,
          delivery_fee_cents: 10_000,
          product_id: product.id,
          customer_id: customer.id,
          delivery_id: delivery.id
        )
      end

      after do
        Transaction.where(id: transaction.id).delete
        Delivery.where(id: delivery.id).delete
        Customer.where(id: customer.id).delete
        Product.where(id: product.id).delete
      end

      it 'returns the transaction' do
        found = repo.find_by_id(transaction.id)

        expect(found).not_to be_nil
        expect(found.reference).to eq('TX-FIND-0001')
      end
    end

    context 'when transaction does not exist' do
      it 'returns nil' do
        found = repo.find_by_id('00000000-0000-0000-0000-000000000000')

        expect(found).to be_nil
      end
    end
  end

  describe '#find_by_reference' do
    let(:product) { Product.create(name: 'Test Product', description: 'Test', price_cents: 100_000, stock: 10) }
    let(:customer) { Customer.create(full_name: 'Test User', identity_document: 12345678, email: 'test@test.com') }
    let(:delivery) { Delivery.create(customer_id: customer.id, address: 'Test', city: 'Test', country: 'CO') }
    let!(:transaction) do
      Transaction.create(
        reference: 'TX-REF-0001',
        status: 'PENDING',
        amount_cents: 100_000,
        base_fee_cents: 5000,
        delivery_fee_cents: 10_000,
        product_id: product.id,
        customer_id: customer.id,
        delivery_id: delivery.id
      )
    end

    after do
      Transaction.where(id: transaction.id).delete
      Delivery.where(id: delivery.id).delete
      Customer.where(id: customer.id).delete
      Product.where(id: product.id).delete
    end

    it 'finds transaction by reference' do
      found = repo.find_by_reference('TX-REF-0001')

      expect(found).not_to be_nil
      expect(found.id).to eq(transaction.id)
    end

    it 'returns nil when reference not found' do
      found = repo.find_by_reference('TX-NONEXISTENT')

      expect(found).to be_nil
    end
  end

  describe '#update_status' do
    let(:product) { Product.create(name: 'Test Product', description: 'Test', price_cents: 100_000, stock: 10) }
    let(:customer) { Customer.create(full_name: 'Test User', identity_document: 12345678, email: 'test@test.com') }
    let(:delivery) { Delivery.create(customer_id: customer.id, address: 'Test', city: 'Test', country: 'CO') }
    let!(:transaction) do
      Transaction.create(
        reference: 'TX-UPDATE-0001',
        status: 'PENDING',
        amount_cents: 100_000,
        base_fee_cents: 5000,
        delivery_fee_cents: 10_000,
        product_id: product.id,
        customer_id: customer.id,
        delivery_id: delivery.id
      )
    end

    after do
      Transaction.where(id: transaction.id).delete
      Delivery.where(id: delivery.id).delete
      Customer.where(id: customer.id).delete
      Product.where(id: product.id).delete
    end

    it 'updates the status' do
      updated = repo.update_status(transaction.id, 'APPROVED')

      expect(updated.status).to eq('APPROVED')
    end

    it 'updates wompi_transaction_id when provided' do
      updated = repo.update_status(transaction.id, 'APPROVED', wompi_transaction_id: 'wompi-123')

      expect(updated.wompi_transaction_id).to eq('wompi-123')
    end

    it 'returns nil when transaction not found' do
      result = repo.update_status('00000000-0000-0000-0000-000000000000', 'APPROVED')

      expect(result).to be_nil
    end
  end

  describe '#next_reference_number' do
    it 'generates reference with timestamp and random hex' do
      reference = repo.next_reference_number

      expect(reference).to match(/^TX-\d{14}-[A-F0-9]{8}$/)
    end

    it 'generates unique references' do
      ref1 = repo.next_reference_number
      ref2 = repo.next_reference_number

      expect(ref1).not_to eq(ref2)
    end
  end

  describe '#mark_fulfilled' do
    let(:product) { Product.create(name: 'Test Product', description: 'Test', price_cents: 100_000, stock: 10) }
    let(:customer) { Customer.create(full_name: 'Test User', identity_document: 12345678, email: 'fulfill@test.com') }
    let(:delivery) { Delivery.create(customer_id: customer.id, address: 'Test', city: 'Test', country: 'CO') }
    let!(:transaction) do
      Transaction.create(
        reference: 'TX-FULFILL-0001',
        status: 'APPROVED',
        amount_cents: 100_000,
        base_fee_cents: 5000,
        delivery_fee_cents: 10_000,
        product_id: product.id,
        customer_id: customer.id,
        delivery_id: delivery.id,
        session_id: 'session-123'
      )
    end

    after do
      Transaction.where(id: transaction.id).delete
      Delivery.where(id: delivery.id).delete
      Customer.where(id: customer.id).delete
      Product.where(id: product.id).delete
    end

    it 'sets fulfilled_at timestamp' do
      updated = repo.mark_fulfilled(transaction.id)

      expect(updated[:fulfilled_at]).not_to be_nil
      expect(updated[:fulfilled_at]).to be_a(Time)
    end

    it 'returns nil when transaction not found' do
      result = repo.mark_fulfilled('00000000-0000-0000-0000-000000000000')

      expect(result).to be_nil
    end
  end

  describe '#create with session_id' do
    let(:product) { Product.create(name: 'Test Product', description: 'Test', price_cents: 100_000, stock: 10) }
    let(:customer) { Customer.create(full_name: 'Test User', identity_document: 12345678, email: 'session@test.com') }
    let(:delivery) { Delivery.create(customer_id: customer.id, address: 'Test', city: 'Test', country: 'CO') }

    let(:attributes) do
      {
        reference: 'TX-SESSION-0001',
        status: 'PENDING',
        amount_cents: 100_000,
        base_fee_cents: 5000,
        delivery_fee_cents: 10_000,
        product_id: product.id,
        customer_id: customer.id,
        delivery_id: delivery.id,
        session_id: 'cart-session-uuid'
      }
    end

    after do
      Transaction.where(reference: 'TX-SESSION-0001').delete
      Delivery.where(id: delivery.id).delete
      Customer.where(id: customer.id).delete
      Product.where(id: product.id).delete
    end

    it 'stores session_id with transaction' do
      transaction = repo.create(attributes)

      expect(transaction[:session_id]).to eq('cart-session-uuid')
    end

    it 'allows nil session_id' do
      attrs_without_session = attributes.except(:session_id)
      transaction = repo.create(attrs_without_session)

      expect(transaction[:session_id]).to be_nil
    end
  end
end
