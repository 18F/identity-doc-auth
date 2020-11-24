require 'spec_helper'
require 'faraday'

RSpec.describe IdentityDocAuth::LexisNexis::Responses::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.true_id_response_success_2 }
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  let(:failure_body_no_liveness) { LexisNexisFixtures.true_id_response_failure_no_liveness }
  let(:failure_body_with_liveness) { LexisNexisFixtures.true_id_response_failure_with_liveness}
  let(:failure_body_with_all_failures) { LexisNexisFixtures.true_id_response_failure_with_all_failures}


  let(:failure_response_no_liveness) do
    instance_double(Faraday::Response, status: 200, body: failure_body_no_liveness)
  end
  let(:failure_response_with_liveness) do
    instance_double(Faraday::Response, status: 200, body: failure_body_with_liveness)
    end
  let(:failure_response_with_all_failures) do
    instance_double(Faraday::Response, status: 200, body: failure_body_with_all_failures)
  end
  let(:communications_error_response) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.communications_error)
  end
  let(:internal_application_error_response) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.internal_application_error)
  end

  let(:exception_notifier) { instance_double('Proc') }

  let(:config) do
    IdentityDocAuth::LexisNexis::Config.new(
      exception_notifier: exception_notifier,
    )
  end

  context 'when the response is a success' do
    it 'is a successful result' do
      expect(described_class.new(success_response, false, config).successful_result?).to eq(true)
    end
    it 'has no error messages' do
      expect(described_class.new(success_response, false, config).error_messages).to be_empty
    end
    it 'has extra attributes' do
      extra_attributes = described_class.new(success_response, false, config).extra_attributes
      expect(extra_attributes).not_to be_empty
    end
    it 'has PII data' do
      pii_from_doc = described_class.new(success_response, false, config).pii_from_doc
      expect(pii_from_doc).not_to be_empty
    end
  end

  context 'when response is not a success' do
    it 'it produces appropriate errors without liveness' do
      output = described_class.new(failure_response_no_liveness, false, config).to_h
      errors = output[:errors]

      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general)
      expect(errors[:general]).to contain_exactly(
        IdentityDocAuth::LexisNexis::Errors::GENERAL_ERROR_NO_LIVENESS,
      )
    end

    it 'it produces appropriate errors with liveness' do
      output = described_class.new(failure_response_with_liveness, true, config).to_h
      errors = output[:errors]

      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general)
      expect(errors[:general]).to contain_exactly(
        IdentityDocAuth::LexisNexis::Errors::GENERAL_ERROR_LIVENESS,
      )
    end

    it 'it produces appropriate errors with liveness and everything failing' do
      output = described_class.new(failure_response_with_all_failures, true, config).to_h
      errors = output[:errors]

      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general)
      expect(errors[:general]).to contain_exactly(
        IdentityDocAuth::LexisNexis::Errors::GENERAL_ERROR_LIVENESS,
      )
    end
  end

  context 'when response is unexpected' do
    it 'it produces reasonable output for communications error' do
      expect(exception_notifier).to receive(:call).
        with(anything, hash_including(:response_info)).once

      output = described_class.new(communications_error_response, false, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info)
    end

    it 'it produces reasonable output for internal application error' do
      expect(exception_notifier).to receive(:call).
        with(anything, hash_including(:response_info)).once

      output = described_class.new(internal_application_error_response, false, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info)
    end
  end
end
