require 'spec_helper'

RSpec.describe Adapters::SequelCustomerRepository do
  let(:repo) { described_class.new }

  describe '#create' do
    let(:attributes) do
      {
        full_name: 'Test Customer',
        identity_document: 12345678,
        email: 'test@customer.com',
        phone: '3001234567'
      }
    end

    after { Customer.where(email: 'test@customer.com').delete }

    it 'creates a customer with given attributes' do
      customer = repo.create(attributes)

      expect(customer.full_name).to eq('Test Customer')
      expect(customer.email).to eq('test@customer.com')
    end

    it 'generates a UUID for id' do
      customer = repo.create(attributes)

      expect(customer.id).to match(/^[0-9a-f-]{36}$/)
    end
  end

  describe '#find_by_id' do
    context 'when customer exists' do
      let!(:customer) { Customer.create(full_name: 'Find Customer', identity_document: 87654321, email: 'find@test.com') }

      after { Customer.where(id: customer.id).delete }

      it 'returns the customer' do
        found = repo.find_by_id(customer.id)

        expect(found).not_to be_nil
        expect(found.full_name).to eq('Find Customer')
      end
    end

    context 'when customer does not exist' do
      it 'returns nil' do
        found = repo.find_by_id('00000000-0000-0000-0000-000000000000')

        expect(found).to be_nil
      end
    end
  end
end
