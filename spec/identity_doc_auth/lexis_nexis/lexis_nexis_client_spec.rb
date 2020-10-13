require 'spec_helper'

RSpec.describe IdentityDocAuth::LexisNexis::LexisNexisClient do
  let(:liveness_enabled) { true }
  let(:workflow) { 'LIVENESS.WORKFLOW' }
  let(:image_upload_url) do
    URI.join(
      "https://lexis.nexis.example.com",
      "/restws/identity/v3/accounts/test_account/workflows/#{workflow}/conversations",
    )
  end

  let(:i18n) do
    FakeI18n.new(
      'doc_auth.errors.lexis_nexis.id_not_verified',
      'doc_auth.errors.lexis_nexis.network_error',
      'doc_auth.errors.lexis_nexis.ref_control_number_check',
      'doc_auth.errors.lexis_nexis.barcode_content_check',
      'doc_auth.errors.lexis_nexis.control_number_check',
      'doc_auth.errors.lexis_nexis.expiration_checks',
      'doc_auth.errors.lexis_nexis.selfie_failure',
      'doc_auth.errors.lexis_nexis.general_error_liveness',
    )
  end

  subject(:client) do
    IdentityDocAuth::LexisNexis::LexisNexisClient.new(
      base_url: "https://lexis.nexis.example.com",
      trueid_account_id: "test_account",
      i18n: i18n,
      trueid_liveness_workflow: 'LIVENESS.WORKFLOW',
      trueid_noliveness_workflow: 'NO.LIVENESS.WORKFLOW',
    )
  end

  describe '#create_document' do
    it 'raises a NotImplemented error' do
      expect { client.create_document }.to raise_error(NotImplementedError)
    end
  end

  describe '#post_front_image' do
    it 'raises a NotImplemented error' do
      expect do
        client.post_front_image(
          instance_id: 123,
          image: DocAuthImageFixtures.document_front_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_back_image' do
    it 'raises a NotImplemented error' do
      expect do
        client.post_back_image(
          instance_id: 123,
          image: DocAuthImageFixtures.document_back_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_selfie' do
    it 'raises a NotImplemented error' do
      expect do
        client.post_selfie(
          instance_id: 123,
          image: DocAuthImageFixtures.selfie_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#get_results' do
    it 'raises a NotImplemented error' do
      expect do
        client.get_results(
          instance_id: 123,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_images' do
    before do
      stub_request(:post, image_upload_url).to_return(
        body: LexisNexisFixtures.true_id_response_success,
      )
    end

    context 'with liveness checking enabled' do
      let(:liveness_enabled) { true }
      let(:workflow) { 'LIVENESS.WORKFLOW' }

      it 'sends an upload image request for the front, back, and selfie images' do
        result = client.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_enabled: liveness_enabled,
        )

        expect(result.success?).to eq(true)
        expect(result.pii_from_doc).to_not be_empty
      end
    end

    context 'with liveness checking disabled' do
      let(:liveness_enabled) { false }
      let(:workflow) { 'NO.LIVENESS.WORKFLOW' }

      it 'sends an upload image request for the front and back DL images' do
        result = client.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: nil,
          liveness_checking_enabled: liveness_enabled,
        )

        expect(result.success?).to eq(true)
        expect(result.class).to eq(IdentityDocAuth::LexisNexis::Responses::TrueIdResponse)
      end
    end

    context 'when the results return failure' do
      it 'returns a FormResponse with failure' do
        stub_request(:post, image_upload_url).to_return(
          body: LexisNexisFixtures.true_id_response_failure,
        )

        result = client.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_enabled: liveness_enabled,
        )

        expect(result.success?).to eq(false)
      end
    end
  end

  context 'when the request is not successful' do
    it 'returns a response with an exception' do
      stub_request(:post, image_upload_url).to_return(body: '', status: 500)

      result = client.post_images(
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        selfie_image: DocAuthImageFixtures.selfie_image,
        liveness_checking_enabled: liveness_enabled,
      )

      expect(result.success?).to eq(false)
      expect(result.errors).to eq({ network: i18n.t('doc_auth.errors.lexis_nexis.network_error') })
      expect(result.exception.message).to eq(
        'IdentityDocAuth::LexisNexis::Requests::TrueIdRequest Unexpected HTTP response 500',
      )
    end
  end

  context 'when there is a networking error' do
    it 'returns a response with an exception' do
      stub_request(:post, image_upload_url).to_raise(Faraday::TimeoutError.new('Connection failed'))

      result = client.post_images(
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        selfie_image: DocAuthImageFixtures.selfie_image,
        liveness_checking_enabled: liveness_enabled,
      )

      expect(result.success?).to eq(false)
      expect(result.errors).to eq({ network: i18n.t('doc_auth.errors.lexis_nexis.network_error') })
      expect(result.exception.message).to eq(
        'Connection failed',
      )
    end
  end
end
