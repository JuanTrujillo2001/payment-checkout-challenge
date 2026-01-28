module Ports
  module CustomerRepository
    def create(attributes)
      raise NotImplementedError
    end

    def find_by_id(id)
      raise NotImplementedError
    end
  end
end
