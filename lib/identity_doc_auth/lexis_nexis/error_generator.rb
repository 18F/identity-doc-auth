# frozen_string_literal: true
require 'identity_doc_auth/errors'

module IdentityDocAuth
  module LexisNexis
    class UnknownTrueIDError < StandardError; end
    class UnknownTrueIDAlert < StandardError; end

    class ErrorGenerator
      attr_reader :config

      def initialize(config)
        @config = config
      end

      # These constants are the key names for the TrueID errors hash that is returned
      ID = :id
      FRONT = :front
      BACK = :back
      SELFIE = :selfie
      GENERAL = :general

      ERROR_KEYS = [
        ID,
        FRONT,
        BACK,
        SELFIE,
        GENERAL,
      ].to_set.freeze

      TRUE_ID_MESSAGES = {
        '1D Control Number Valid': { type: BACK, msg_key: Errors::REF_CONTROL_NUMBER_CHECK },
        '2D Barcode Content': { type: BACK, msg_key: Errors::BARCODE_CONTENT_CHECK },
        '2D Barcode Read': { type: BACK, msg_key: Errors::BARCODE_READ_CHECK },
        'Birth Date Crosscheck': { type: ID, msg_key: Errors::BIRTH_DATE_CHECKS },
        'Birth Date Valid': { type: ID, msg_key: Errors::BIRTH_DATE_CHECKS },
        'Control Number Crosscheck': { type: BACK, msg_key: Errors::CONTROL_NUMBER_CHECK },
        'Document Classification': { type: ID, msg_key: Errors::ID_NOT_RECOGNIZED },
        'Document Crosscheck Aggregation': { type: ID, msg_key: Errors::DOC_CROSSCHECK },
        'Document Expired': { type: ID, msg_key: Errors::EXPIRATION_CHECKS },
        'Document Number Crosscheck': { type: ID, msg_key: Errors::DOC_NUMBER_CHECKS },
        'Expiration Date Crosscheck': { type: ID, msg_key: Errors::EXPIRATION_CHECKS },
        'Expiration Date Valid': { type: ID, msg_key: Errors::EXPIRATION_CHECKS },
        'Full Name Crosscheck': { type: ID, msg_key: Errors::FULL_NAME_CHECK },
        'Issue Date Crosscheck': { type: ID, msg_key: Errors::ISSUE_DATE_CHECKS },
        'Issue Date Valid': { type: ID, msg_key: Errors::ISSUE_DATE_CHECKS },
        'Layout Valid': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
        'Near-Infrared Response': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
        'Sex Crosscheck': { type: ID, msg_key: Errors::SEX_CHECK },
        'Visible Color Response': { type: ID, msg_key: Errors::VISIBLE_COLOR_CHECK },
        'Visible Pattern': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
        'Visible Photo Characteristics': { type: FRONT, msg_key: Errors::VISIBLE_PHOTO_CHECK },
      }.freeze

      # rubocop:disable Metrics/PerceivedComplexity
      def generate_trueid_errors(response_info, liveness_enabled)
        user_error_count = response_info[:AlertFailureCount]

        unknown_fail_count = scan_for_unknown_alerts(response_info)
        user_error_count -= unknown_fail_count

        errors = get_error_messages(liveness_enabled, response_info)
        user_error_count += 1 if errors.include?(SELFIE)

        if user_error_count < 1
          e = UnknownTrueIDError.new('LN TrueID failure escaped without useful errors')
          config.exception_notifier&.call(e, response_info: response_info)

          return { GENERAL => [general_error(liveness_enabled)] }
        # if the user_error_count is 1 it is just passed along
        elsif user_error_count > 1
          # Simplify multiple errors into a single error for the user
          error_fields = errors.keys
          if error_fields.length == 1
            case error_fields.first
            when ID
              errors[ID] = Set[general_error(false)]
            when FRONT
              errors[FRONT] = Set[Errors::MULTIPLE_FRONT_ID_FAILURES]
            when BACK
              errors[BACK] = Set[Errors::MULTIPLE_BACK_ID_FAILURES]
            end
          elsif error_fields.length > 1
            return { GENERAL => [general_error(liveness_enabled)] } if error_fields.include?(SELFIE)

            # If we don't have a selfie error don't give the message suggesting retaking selfie.
            return { GENERAL => [general_error(false)] }
          end
        end

        errors.transform_values(&:to_a)
      end
      # rubocop:enable Metrics/PerceivedComplexity

      # private

      def get_error_messages(liveness_enabled, response_info)
        errors = Hash.new { |hash, key| hash[key] = Set.new }

        if response_info[:DocAuthResult] != 'Passed'
          response_info[:Alerts][:failed]&.each do |alert|
            alert_msg_hash = TRUE_ID_MESSAGES[alert[:name].to_sym]

            if alert_msg_hash.present?
              errors[alert_msg_hash[:type]] << alert_msg_hash[:msg_key]
            end
          end
        end

        pm_results = response_info[:PortraitMatchResults] || {}
        if liveness_enabled && pm_results.dig(:FaceMatchResult) != 'Pass'
          errors[SELFIE] << Errors::SELFIE_FAILURE
        end

        errors
      end

      def general_error(liveness_enabled)
        if liveness_enabled
          Errors::GENERAL_ERROR_LIVENESS
        else
          Errors::GENERAL_ERROR_NO_LIVENESS
        end
      end

      def scan_for_unknown_alerts(response_info)
        all_alerts = [*response_info[:Alerts][:failed], *response_info[:Alerts][:passed]]
        unknown_fail_count = 0

        unknown_alerts = []
        all_alerts.each do |alert|
          if TRUE_ID_MESSAGES[alert[:name].to_sym].blank?
            unknown_alerts.push(alert[:name])

            if alert[:result] != 'Passed'
              unknown_fail_count += 1
            end
          end
        end

        return 0 if unknown_alerts.empty?

        message = 'LN TrueID responded with alert name(s) we do not handle: ' + unknown_alerts.to_s
        e = UnknownTrueIDAlert.new(message)
        config.exception_notifier&.call(e, response_info: response_info)

        unknown_fail_count
      end
    end
  end
end
