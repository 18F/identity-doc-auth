require 'yaml'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'
require 'uri'

module IdentityDocAuth
  module Mock
    class ResultResponseBuilder
      DEFAULT_PII_FROM_DOC = {
        first_name: 'FAKEY',
        middle_name: nil,
        last_name: 'MCFAKERSON',
        address1: '1 FAKE RD',
        address2: nil,
        city: 'GREAT FALLS',
        state: 'MT',
        zipcode: '59010',
        dob: '10/06/1938',
        state_id_number: '1111111111111',
        state_id_jurisdiction: 'ND',
        state_id_type: 'drivers_license',
        phone: nil,
      }.freeze

      attr_reader :uploaded_file

      def initialize(uploaded_file)
        @uploaded_file = uploaded_file.to_s
      end

      def call
        IdentityDocAuth::Response.new(
          success: success?,
          errors: errors,
          pii_from_doc: pii_from_doc,
          extra: {
            result: success? ? 'Passed' : 'Caution',
            billed: true,
          },
        )
      end

      private

      def errors
        error = parsed_data_from_uploaded_file&.dig('friendly_error')
        if error.blank?
          {}
        else
          { results: [error] }
        end
      end

      def parsed_data_from_uploaded_file
        return @parsed_data_from_uploaded_file if defined?(@parsed_data_from_uploaded_file)

        @parsed_data_from_uploaded_file = parse_uri || parse_yaml
      end

      def parse_uri
        uri = URI.parse(uploaded_file.chomp)
        if uri.scheme == 'data'
          {}
        else
          { 'friendly_error' => "parsed URI, but scheme was #{uri.scheme} (expected data)" }
        end
      rescue URI::InvalidURIError
        # no-op, allows falling through to YAML parseing
      end

      def parse_yaml
        data = YAML.safe_load(uploaded_file)
        if data.kind_of?(Hash)
          data
        else
          { 'friendly_error' => "YAML data should have been a hash, got #{data.class}" }
        end
      rescue Psych::SyntaxError
        {}
      end

      def pii_from_doc
        if parsed_data_from_uploaded_file.present?
          raw_pii = parsed_data_from_uploaded_file['document']
          raw_pii&.symbolize_keys || {}
        else
          DEFAULT_PII_FROM_DOC
        end
      end

      def success?
        errors.blank?
      end
    end
  end
end
