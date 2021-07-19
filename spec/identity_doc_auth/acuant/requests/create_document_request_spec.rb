require 'spec_helper'

RSpec.describe IdentityDocAuth::Acuant::Requests::CreateDocumentRequest do
  describe '#fetch' do
    let(:assure_id_url) { 'https://acuant.assureid.example.com' }
    let(:assure_id_subscription_id) { '1234567' }
    let(:cropping_mode) { IdentityDocAuth::CroppingModes::NONE }

    let(:url) { URI.join(assure_id_url, '/AssureIDService/Document/Instance') }
    let(:request_body) do
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
        ImageCroppingMode: cropping_mode,
        ManualDocumentType: nil,
        ProcessMode: 0,
        SubscriptionId: assure_id_subscription_id,
      }.to_json
    end
    let(:response_body) do
      AcuantFixtures.create_document_response
    end

    let(:config) do
      IdentityDocAuth::Acuant::Config.new(
        assure_id_url: assure_id_url,
        assure_id_subscription_id: assure_id_subscription_id,
      )
    end

    it 'sends a well formed request and returns a response with the instance ID' do
      request_stub = stub_request(:post, url).with(
        body: request_body,
      ).to_return(
        body: response_body,
      )

      request = described_class.new(config: config)
      request.cropping_mode = cropping_mode
      response = request.fetch

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(response.instance_id).to eq('this-is-a-test-instance-id') # instance ID from fixture
      expect(request_stub).to have_been_requested
    end
  end
end
