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

      attr_reader :uploaded_file, :config, :liveness_enabled

      def initialize(uploaded_file, config, liveness_enabled)
        @uploaded_file = uploaded_file.to_s
        @config = config
        @liveness_enabled = liveness_enabled
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
        file_data = parsed_data_from_uploaded_file

        if file_data.blank?
          {}
        else
          image_metrics = file_data&.dig('image_metrics') || {}
          failed = file_data&.dig('failed_alerts') || []
          passed = file_data&.dig('passed_alerts') || []
          liveness_result = file_data&.dig('liveness_result') || ''

          if [image_metrics,failed, passed, liveness_result].any?(&:present?)
            fake_response_info = create_response_info(
              image_metrics: image_metrics&.symbolize_keys,
              failed: failed.map!(&:symbolize_keys),
              passed: passed.map!(&:symbolize_keys),
              liveness_result: liveness_result
            )
            ErrorGenerator.new(config).generate_doc_auth_errors(fake_response_info)
          else
            # general is the key for errors that come from parsing
            file_data if file_data.include?(:general)
          end
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
          { general: ["parsed URI, but scheme was #{uri.scheme} (expected data)"] }
        end
      rescue URI::InvalidURIError
        # no-op, allows falling through to YAML parsing
      end

      def parse_yaml
        data = YAML.safe_load(uploaded_file)
        if data.kind_of?(Hash)
          data
        else
          { general: ["YAML data should have been a hash, got #{data.class}"] }
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

      DEFAULT_FAILED_ALERTS = [{ name: '2D Barcode Read', result: 'Failed' }].freeze
      DEFAULT_IMAGE_METRICS = {
        front: {
          "VerticalResolution" => 300,
          "HorizontalResolution" => 300,
          "GlareMetric" => 50,
          "SharpnessMetric" => 50,
        },
        back: {
          "VerticalResolution" => 300,
          "HorizontalResolution" => 300,
          "GlareMetric" => 50,
          "SharpnessMetric" => 50,
        }
      }.freeze

      def create_response_info(
        doc_auth_result: 'Failed',
        passed: [],
        failed: DEFAULT_FAILED_ALERTS,
        liveness_result: nil,
        image_metrics: DEFAULT_IMAGE_METRICS
      )
        merged_image_metrics = DEFAULT_IMAGE_METRICS.deep_merge(image_metrics)
        {
          vendor: 'Mock',
          doc_auth_result: doc_auth_result,
          processed_alerts: {
            passed: passed,
            failed: failed,
          },
          alert_failure_count: failed&.count.to_i,
          image_metrics: merged_image_metrics,
          liveness_enabled: liveness_enabled,
          portrait_match_results: { FaceMatchResult: liveness_result },
        }
      end
    end
  end
end
