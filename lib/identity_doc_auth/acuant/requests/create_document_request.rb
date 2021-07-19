require 'identity_doc_auth/acuant/request'
require 'identity_doc_auth/acuant/responses/create_document_response'

module IdentityDocAuth
  module Acuant
    module Requests
      class CreateDocumentRequest < IdentityDocAuth::Acuant::Request
        def initialize(config:, cropping_mode:)
          super(config: config)

          @cropping_mode = cropping_mode
        end

        def path
          '/AssureIDService/Document/Instance'
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
        end

        def body
          {
            AuthenticationSensitivity: 0,
            ClassificationMode: 0,
            Device: {
              HasContactlessChipReader: false,
              HasMagneticStripeReader: false,
              SerialNumber: 'xxxxx',
              Type: {
                Manufacturer: 'Login.gov',
                Model: 'Doc Auth 1.0',
                SensorType: '3',
              },
            },
            ImageCroppingExpectedSize: '1',
            ImageCroppingMode: @cropping_mode,
            ManualDocumentType: nil,
            ProcessMode: 0,
            SubscriptionId: config.assure_id_subscription_id,
          }.to_json
        end

        def handle_http_response(response)
          IdentityDocAuth::Acuant::Responses::CreateDocumentResponse.new(response)
        end

        def method
          :post
        end

        def metric_name
          'acuant_doc_auth_create_document'
        end
      end
    end
  end
end
