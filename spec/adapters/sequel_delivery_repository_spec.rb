require 'spec_helper'

RSpec.describe Adapters::SequelDeliveryRepository do
  let(:repo) { described_class.new }

  describe '#create' do
    let!(:customer) { Customer.create(full_name: 'Delivery Customer', identity_document: 12345678, email: 'delivery@test.com') }

    let(:attributes) do
      {
        customer_id: customer.id,
        address: 'Calle 123 #45-67',
        city: 'Bogotá',
        country: 'Colombia'
      }
    end

    after do
      Delivery.where(customer_id: customer.id).delete
      Customer.where(id: customer.id).delete
    end

    it 'creates a delivery with given attributes' do
      delivery = repo.create(attributes)

      expect(delivery.address).to eq('Calle 123 #45-67')
      expect(delivery.city).to eq('Bogotá')
      expect(delivery.country).to eq('Colombia')
    end

    it 'generates a UUID for id' do
      delivery = repo.create(attributes)

      expect(delivery.id).to match(/^[0-9a-f-]{36}$/)
    end

    it 'associates with customer' do
      delivery = repo.create(attributes)

      expect(delivery.customer_id).to eq(customer.id)
    end
  end

  describe '#find_by_id' do
    let!(:customer) { Customer.create(full_name: 'Find Delivery Customer', identity_document: 87654321, email: 'finddelivery@test.com') }
    let!(:delivery) { Delivery.create(customer_id: customer.id, address: 'Find Address', city: 'Medellín', country: 'Colombia') }

    after do
      Delivery.where(id: delivery.id).delete
      Customer.where(id: customer.id).delete
    end

    context 'when delivery exists' do
      it 'returns the delivery' do
        found = repo.find_by_id(delivery.id)

        expect(found).not_to be_nil
        expect(found.address).to eq('Find Address')
      end
    end

    context 'when delivery does not exist' do
      it 'returns nil' do
        found = repo.find_by_id('00000000-0000-0000-0000-000000000000')

        expect(found).to be_nil
      end
    end
  end
end
