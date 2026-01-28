module Ports
  module PaymentGateway
    def tokenize_card(card_data)
      raise NotImplementedError
    end

    def create_payment_source(token:, customer_email:, acceptance_token:)
      raise NotImplementedError
    end

    def create_transaction(amount_cents:, currency:, payment_source_id:, reference:, customer_email:, installments:)
      raise NotImplementedError
    end

    def get_transaction(transaction_id)
      raise NotImplementedError
    end

    def get_acceptance_token
      raise NotImplementedError
    end
  end
end
