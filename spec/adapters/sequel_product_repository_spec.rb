require 'spec_helper'

RSpec.describe Adapters::SequelProductRepository do
  let(:repo) { described_class.new }

  describe '#find_by_id' do
    context 'when product exists' do
      let!(:product) { Product.create(name: 'Test Product', description: 'Test Desc', price_cents: 100_000, stock: 10) }

      after { Product.where(id: product.id).delete }

      it 'returns the product' do
        found = repo.find_by_id(product.id)

        expect(found).not_to be_nil
        expect(found.name).to eq('Test Product')
      end
    end

    context 'when product does not exist' do
      it 'returns nil' do
        found = repo.find_by_id('00000000-0000-0000-0000-000000000000')

        expect(found).to be_nil
      end
    end
  end

  describe '#update_stock' do
    let!(:product) { Product.create(name: 'Stock Product', description: 'Test', price_cents: 100_000, stock: 10) }

    after { Product.where(id: product.id).delete }

    it 'updates the stock' do
      updated = repo.update_stock(product.id, 5)

      expect(updated.stock).to eq(5)
    end

    it 'returns nil when product not found' do
      result = repo.update_stock('00000000-0000-0000-0000-000000000000', 5)

      expect(result).to be_nil
    end
  end
end
