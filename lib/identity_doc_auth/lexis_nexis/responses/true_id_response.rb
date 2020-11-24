# frozen_string_literal: true

require 'identity_doc_auth/lexis_nexis/error_generator'
require 'identity_doc_auth/lexis_nexis/responses/lexis_nexis_response'

module IdentityDocAuth
  module LexisNexis
    module Responses
      class LexisNexisResponseError < StandardError; end
      class TrueIdResponse < LexisNexisResponse
        attr_reader :config

        def initialize(http_response, liveness_checking_enabled, config)
          @liveness_checking_enabled = liveness_checking_enabled
          @config = config

          super http_response
        end

        def successful_result?
          transaction_status_passed? &&
            true_id_product.present? &&
            product_status_passed? &&
            doc_auth_result_passed?
        end

        def error_messages
          return {} if successful_result?

          if true_id_product.present?
            ErrorGenerator.new(config).generate_trueid_errors(response_info, @liveness_checking_enabled)
          else
            { network: true } # return a generic technical difficulties error to user
          end
        end

        def extra_attributes
          if true_id_product.present?
            attrs = response_info.merge(true_id_product[:AUTHENTICATION_RESULT])
            attrs.reject do |k, _v|
              PII_DETAILS.include? k
            end
          else
            response_status = {
              lexis_nexis_status: parsed_response_body[:Status],
              lexis_nexis_info: parsed_response_body.dig(:Information)
            }
            e = LexisNexisResponseError.new("Unexpected LN Response: TrueID response not found.")

            config.exception_notifier&.call(e, response_info: response_status)
            return response_status
          end
        end

        def pii_from_doc
          return {} unless true_id_product.present?

          true_id_product[:AUTHENTICATION_RESULT].select do |k, _v|
            PII_DETAILS.include? k
          end
        end

        private

        def response_info
          @response_info ||= create_response_info
        end

        def create_response_info
          alerts = parse_alerts

          {
            ConversationId: conversation_id,
            Reference: reference,
            LivenessChecking: @liveness_checking_enabled,
            ProductType: 'TrueID',
            TransactionReasonCode: transaction_reason_code,
            IdentityDocAuthResult: doc_auth_result,
            Alerts: alerts,
            AlertFailureCount: alerts[:failed].length,
            PortraitMatchResults: true_id_product[:PORTRAIT_MATCH_RESULT],
            ImageMetrics: parse_image_metrics,
          }
        end

        def product_status_passed?
          product_status == 'pass'
        end

        def doc_auth_result_passed?
          doc_auth_result == 'Passed'
        end

        def doc_auth_result
          true_id_product.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
        end

        def product_status
          true_id_product.dig(:ProductStatus)
        end

        def true_id_product
          products[:TrueID] if products.present?
        end

        def parse_alerts
          new_alerts = { passed: [], failed: [] }
          all_alerts = true_id_product[:AUTHENTICATION_RESULT].select do |key|
            key.start_with?('Alert_')
          end

          alert_names = all_alerts.select { |key| key.end_with?('_AlertName') }
          alert_names.each do |alert_name, _v|
            alert_prefix = alert_name.scan(/Alert_\d{1,2}_/).first
            alert = combine_alert_data(all_alerts, alert_prefix)
            if alert[:result] == 'Passed'
              new_alerts[:passed].push(alert)
            else
              new_alerts[:failed].push(alert)
            end
          end

          new_alerts
        end

        def combine_alert_data(all_alerts, alert_name)
          new_alert_data = {}
          # Get the set of Alerts that are all the same number (e.g. Alert_11)
          alert_set = all_alerts.select { |key| key.match?(alert_name) }

          alert_set.each do |key, value|
            new_alert_data[:alert] = alert_name.delete_suffix('_')
            new_alert_data[:name] = value if key.end_with?('_AlertName')
            new_alert_data[:result] = value if key.end_with?('_AuthenticationResult')
            new_alert_data[:region] = value if key.end_with?('_Regions')
          end

          new_alert_data
        end

        def parse_image_metrics
          image_metrics = {}

          true_id_product[:ParameterDetails].each do |detail|
            next unless detail[:Group] == 'IMAGE_METRICS_RESULT'

            inner_val = detail.dig(:Values).collect { |value| value.dig(:Value) }
            image_metrics[detail[:Name]] = inner_val
          end

          transform_metrics(image_metrics)
        end

        def transform_metrics(img_metrics)
          new_metrics = {}
          img_metrics['Side']&.each_with_index do |side, i|
            new_metrics[side] = img_metrics.transform_values { |v| v[i] }
          end

          new_metrics
        end
      end
    end
  end
end
