module IdentityDocAuth
  module Acuant
    # https://documentation.help/AssureID-Connect/Error%20Codes.html
    # 438 and 439 are frequent errors that we do not want to be notified of
    IGNORED_ERROR_CODES = Set[438, 439]

    class Request
      attr_reader :config

      def initialize(config:)
        @config = config
      end

      def path
        raise NotImplementedError
      end

      def body
        raise NotImplementedError
      end

      def handle_http_response(_response)
        raise NotImplementedError
      end

      def method
        :get
      end

      def url
        URI.join(config.assure_id_url, path)
      end

      def headers
        {
          'Accept' => 'application/json',
        }
      end

      def fetch
        http_response = send_http_request
        return handle_invalid_response(http_response) unless http_response.success?

        handle_http_response(http_response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        handle_connection_error(e)
      end

      private

      def send_http_request
        case method.downcase.to_sym
        when :post
          send_http_post_request
        when :get
          send_http_get_request
        end
      end

      def send_http_get_request
        faraday_connection.get
      end

      def send_http_post_request
        faraday_connection.post do |req|
          req.body = body
        end
      end

      def faraday_connection
        retry_options = {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [404],
          retry_block: lambda do |_env, _options, retries, exc|
            send_exception_notification(exc, retry: retries)
          end,
        }

        Faraday.new(request: faraday_request_params, url: url.to_s, headers: headers) do |conn|
          conn.basic_auth(
            config.assure_id_username,
            config.assure_id_password,
          )
          conn.request :retry, retry_options
          conn.adapter :net_http
        end
      end

      def faraday_request_params
        timeout = config.timeout&.to_i || 45
        { open_timeout: timeout, timeout: timeout }
      end

      def handle_invalid_response(http_response)
        message = [
          self.class.name,
          'Unexpected HTTP response',
          http_response.status,
        ].join(' ')
        exception = IdentityDocAuth::RequestError.new(message, http_response.status)
        send_exception_notification(exception)
        IdentityDocAuth::Response.new(
          success: false,
          errors: { network: true },
          exception: exception,
        )
      end

      def handle_connection_error(exception)
        send_exception_notification(exception)
        IdentityDocAuth::Response.new(
          success: false,
          errors: { network: true },
          exception: exception,
        )
      end

      def send_exception_notification(exception, custom_params = nil)
        return if exception.is_a?(IdentityDocAuth::RequestError) &&
          IGNORED_ERROR_CODES.include?(exception.error_code)
        config.exception_notifier&.call(exception, custom_params)
      end
    end
  end
end
