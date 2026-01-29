require 'spec_helper'

RSpec.describe Adapters::SequelCartRepository do
  let(:repo) { described_class.new }
  let(:session_id) { SecureRandom.uuid }
  let!(:product) { Product.create(name: 'Cart Test Product', description: 'Test', price_cents: 100_000, stock: 10) }

  after do
    CartItem.where(session_id: session_id).delete
    Product.where(id: product.id).delete
  end

  describe '#add_item' do
    it 'creates a new cart item' do
      item = repo.add_item(session_id, product.id, 2)

      expect(item.session_id).to eq(session_id)
      expect(item.product_id).to eq(product.id)
      expect(item.quantity).to eq(2)
    end

    it 'increments quantity if item already exists' do
      repo.add_item(session_id, product.id, 2)
      item = repo.add_item(session_id, product.id, 3)

      expect(item.quantity).to eq(5)
    end

    it 'uses default quantity of 1' do
      item = repo.add_item(session_id, product.id)

      expect(item.quantity).to eq(1)
    end
  end

  describe '#get_items' do
    before do
      repo.add_item(session_id, product.id, 3)
    end

    it 'returns all items for session' do
      items = repo.get_items(session_id)

      expect(items.length).to eq(1)
      expect(items.first.product_id).to eq(product.id)
    end

    it 'returns empty array for unknown session' do
      items = repo.get_items(SecureRandom.uuid)

      expect(items).to be_empty
    end
  end

  describe '#update_quantity' do
    before do
      repo.add_item(session_id, product.id, 2)
    end

    it 'updates the quantity' do
      item = repo.update_quantity(session_id, product.id, 5)

      expect(item.quantity).to eq(5)
    end

    it 'removes item if quantity is 0 or less' do
      result = repo.update_quantity(session_id, product.id, 0)

      expect(result).to be_nil
      expect(repo.get_items(session_id)).to be_empty
    end

    it 'returns nil if item not found' do
      result = repo.update_quantity(session_id, SecureRandom.uuid, 5)

      expect(result).to be_nil
    end
  end

  describe '#remove_item' do
    before do
      repo.add_item(session_id, product.id, 2)
    end

    it 'removes the item from cart' do
      repo.remove_item(session_id, product.id)

      expect(repo.get_items(session_id)).to be_empty
    end
  end

  describe '#clear' do
    let!(:product2) { Product.create(name: 'Cart Test Product 2', description: 'Test', price_cents: 200_000, stock: 5) }

    before do
      repo.add_item(session_id, product.id, 2)
      repo.add_item(session_id, product2.id, 1)
    end

    after do
      Product.where(id: product2.id).delete
    end

    it 'removes all items for session' do
      repo.clear(session_id)

      expect(repo.get_items(session_id)).to be_empty
    end
  end
end
