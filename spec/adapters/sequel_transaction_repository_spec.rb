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
    it 'generates reference with current year' do
      reference = repo.next_reference_number

      expect(reference).to match(/^TX-#{Time.now.year}-\d{4}$/)
    end

    it 'increments the counter' do
      ref1 = repo.next_reference_number

      expect(ref1).to match(/^TX-\d{4}-\d{4}$/)
    end
  end
end
