require "httparty"
require "digest"
require_relative "../ports/payment_gateway"

module Adapters
  class WompiPaymentGateway
    include Ports::PaymentGateway
    include HTTParty

    base_uri ENV["WOMPI_BASE_URL"] || "https://sandbox.wompi.co/v1"

    def initialize
      @public_key = ENV["WOMPI_PUBLIC_KEY"]
      @private_key = ENV["WOMPI_PRIVATE_KEY"]
      @integrity_key = ENV["WOMPI_INTEGRITY_KEY"]
    end

    def tokenize_card(card_data)
      response = self.class.post(
        "/tokens/cards",
        headers: auth_headers(:public),
        body: {
          number: card_data[:number],
          cvc: card_data[:cvc],
          exp_month: card_data[:exp_month],
          exp_year: card_data[:exp_year],
          card_holder: card_data[:card_holder]
        }.to_json
      )

      parse_response(response)
    end

    def create_payment_source(token:, customer_email:, acceptance_token:)
      response = self.class.post(
        "/payment_sources",
        headers: auth_headers(:private),
        body: {
          type: "CARD",
          token: token,
          customer_email: customer_email,
          acceptance_token: acceptance_token
        }.to_json
      )

      parse_response(response)
    end

    def create_transaction(amount_cents:, currency:, payment_source_id:, reference:, customer_email:, installments:)
      signature = generate_signature(reference, amount_cents, currency)

      response = self.class.post(
        "/transactions",
        headers: auth_headers(:private),
        body: {
          amount_in_cents: amount_cents,
          currency: currency,
          signature: signature,
          customer_email: customer_email,
          payment_method: {
            installments: installments
          },
          reference: reference,
          payment_source_id: payment_source_id
        }.to_json
      )

      parse_response(response)
    end

    def get_transaction(transaction_id)
      response = self.class.get(
        "/transactions/#{transaction_id}",
        headers: auth_headers(:private)
      )

      parse_response(response)
    end

    def get_acceptance_token
      response = self.class.get("/merchants/#{@public_key}")
      
      if response.success?
        { success: true, data: response.parsed_response["data"]["presigned_acceptance"] }
      else
        { success: false, error: response.parsed_response }
      end
    end

    private

    def auth_headers(key_type)
      key = key_type == :public ? @public_key : @private_key
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{key}"
      }
    end

    def generate_signature(reference, amount_cents, currency)
      data = "#{reference}#{amount_cents}#{currency}#{@integrity_key}"
      Digest::SHA256.hexdigest(data)
    end

    def parse_response(response)
      if response.success?
        { success: true, data: response.parsed_response["data"] }
      else
        { success: false, error: response.parsed_response, status: response.code }
      end
    end
  end
end
