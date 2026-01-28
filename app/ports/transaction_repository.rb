module Ports
  module TransactionRepository
    def create(attributes)
      raise NotImplementedError
    end

    def find_by_id(id)
      raise NotImplementedError
    end

    def find_by_reference(reference)
      raise NotImplementedError
    end

    def update_status(id, status, wompi_transaction_id: nil)
      raise NotImplementedError
    end

    def next_reference_number
      raise NotImplementedError
    end
  end
end
