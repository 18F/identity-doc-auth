require 'spec_helper'

RSpec.describe IdentityDocAuth::Acuant::Request do
  let(:assure_id_url) { 'https://acuant.assureid.example.com' }
  let(:assure_id_username) { 'acuant.username' }
  let(:assure_id_password) { 'acuant.password' }

  let(:path) { '/test/path' }
  let(:full_url) { URI.join(assure_id_url, path) }
  let(:request_body) { 'test request body' }
  let(:request_headers) do
    username = assure_id_username
    password = assure_id_password
    {
      'Authorization' => [
        'Basic',
        Base64.strict_encode64("#{username}:#{password}"),
      ].join(' '),
      'Accept' => 'application/json',
    }
  end
  let(:request_method) { :get }

  let(:exception_notifier) { instance_double('Proc') }

  let(:config) do
    IdentityDocAuth::Acuant::Config.new(
      assure_id_url: assure_id_url,
      assure_id_username: assure_id_username,
      assure_id_password: assure_id_password,
      exception_notifier: exception_notifier,
    )
  end

  subject do
    request = described_class.new(config: config)
    allow(request).to receive(:path).and_return(path)
    allow(request).to receive(:body).and_return(request_body)
    allow(request).to receive(:method).and_return(request_method)
    request
  end

  describe '#fetch' do
    context 'when the request resolves with a 200' do
      it 'calls handle_http_response on the subclass' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response.body.upcase
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 200)

        response = subject.fetch

        expect(response).to eq('TEST RESPONSE BODY')
      end
    end

    context 'when the request is a post instead of a get' do
      let(:request_method) { :post }

      it 'sends a post request with a request body' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response.body.upcase
        end

        stub_request(:post, full_url).
          with(headers: request_headers, body: request_body).
          to_return(body: 'test response body', status: 200)

        response = subject.fetch

        expect(response).to eq('TEST RESPONSE BODY')
      end
    end

    context 'when the request resolves with a non 200 status' do
      it 'returns a response with an exception' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 404)
        allow(exception_notifier).to receive(:call)

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(network: true)
        expect(response.exception.message).to eq(
          'IdentityDocAuth::Acuant::Request Unexpected HTTP response 404',
        )
      end
    end

    context 'when the request resolves with retriable error then succeeds it only retries once' do
      it 'calls exception_notifier each retry' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 404 },
            { body: 'test response body', status: 200 },
          )

        expect(exception_notifier).to receive(:call).
          with(anything, hash_including(:retry)).once

        response = subject.fetch

        expect(response.success?).to eq(true)
      end
    end

    context 'when the request resolves with a 404 status it retries' do
      it 'calls exception_notifier each retry' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 404 },
            { body: 'test response body', status: 404 },
          )

        expect(exception_notifier).to receive(:call).
          with(RuntimeError).once

        expect(exception_notifier).to receive(:call).
          with(anything, hash_including(:retry)).twice

        response = subject.fetch

        expect(response.success?).to eq(false)
      end
    end

    context 'when the request resolves with a 438 status it retries' do
      it 'calls exception_notifier each retry' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 438 },
            { body: 'test response body', status: 438 },
          )

        expect(exception_notifier).to receive(:call).
          with(RuntimeError).once

        expect(exception_notifier).to receive(:call).
          with(anything, hash_including(:retry)).twice

        response = subject.fetch

        expect(response.success?).to eq(false)
      end
    end

    context 'when the request resolves with a 438 status it retries' do
      it 'calls exception_notifier each retry' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 439 },
            { body: 'test response body', status: 439 },
          )

        expect(exception_notifier).to receive(:call).
          with(RuntimeError).once

        expect(exception_notifier).to receive(:call).
          with(anything, hash_including(:retry)).twice

        response = subject.fetch

        expect(response.success?).to eq(false)
      end
    end

    context 'when the request times out' do
      it 'returns a response with a timeout message and exception and notifies NewRelic' do
        stub_request(:get, full_url).to_timeout

        expect(exception_notifier).to receive(:call)

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(network: true)
        expect(response.exception).to be_a(Faraday::ConnectionFailed)
      end
    end
  end
end
