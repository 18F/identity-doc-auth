require 'spec_helper'

RSpec.describe IdentityDocAuth::Acuant::Responses::GetResultsResponse do
  let(:config) do
    IdentityDocAuth::Acuant::Config.new
  end
  subject(:response) { described_class.new(http_response, config) }

  context 'with a successful result' do
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: AcuantFixtures.get_results_response_success,
      )
    end
    let(:raw_alerts) { JSON.parse(AcuantFixtures.get_results_response_success)['Alerts'] }
    let(:raw_regions) { JSON.parse(AcuantFixtures.get_results_response_success)['Regions'] }

    it 'returns a successful response with no errors' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil

      response_hash = response.to_h

      expected_hash = {
        success: true,
        errors: {},
        exception: nil,
        billed: true,
        result: 'Passed',
        processed_alerts: a_hash_including(
          failed: all(a_hash_including(:name, :result)),
          passed: all(a_hash_including(:name, :result))),
        image_metrics: a_hash_including(:back, :front),
        alert_failure_count: 2,
        raw_alerts: raw_alerts,
        raw_regions: raw_regions,
      }

      processed_alerts = response_hash[:processed_alerts]
      expected_alerts = {
        passed:
          a_collection_including(
            a_hash_including(side: :front, region: 'Flag Pattern'),
            a_hash_including(side: :front, region: 'Lower Data Labels Right')
          )
      }

      expect(response_hash).to match(expected_hash)
      expect(processed_alerts).to include(expected_alerts)
      expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::PASSED)
      expect(response.result_code.billed?).to eq(true)
    end

    it 'parsed PII from the doc' do
      # The PII from the response fixture
      expect(response.pii_from_doc).to eq(
        first_name: 'JANE',
        middle_name: nil,
        last_name: 'DOE',
        address1: '1000 E AVENUE E',
        city: 'BISMARCK',
        state: 'ND',
        zipcode: '58501',
        dob: '04/01/1984',
        state_id_number: 'DOE-84-1165',
        state_id_jurisdiction: 'ND',
        state_id_type: 'drivers_license',
      )
    end
  end

  context 'with an attention result' do
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: {
          Result: 5,
          Alerts: alerts,
        }.to_json,
      )
    end

    context 'when the only unsuccessful alert is attention barcode could not be read' do
      let(:alerts) do
        [{ Result: 5, Disposition: 'The 2D barcode could not be read' },
         { Result: 1, Disposition: 'The birth date is valid' }]
      end

      it 'is a successful result' do
        expect(response.success?).to eq(true)
      end
    end

    context 'when there are other unsuccessful alerts' do
      let(:alerts) do
        [{ Result: 5, Disposition: 'The 2D barcode could not be read' },
         { Result: 4, Disposition: 'The birth dates do not match' }]
      end

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end
  end

  context 'with a failed result' do
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: AcuantFixtures.get_results_response_failure,
      )
    end
    let(:raw_alerts) { JSON.parse(AcuantFixtures.get_results_response_success)['Alerts'] }

    it 'returns an unsuccessful response with errors' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(
        # This is the error message for the error in the response fixture
        results: ['The document type could not be determined'],
      )
      expect(response.exception).to be_nil
      expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
      expect(response.result_code.billed?).to eq(false)
    end

    context 'when with an acuant error message' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Alerts'].first['Disposition'] = 'This message does not have a key'
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns the untranslated error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: ['This message does not have a key'],
        )
        expect(response.exception).to be_nil
      end
    end

    context 'when multiple alerts have the same friendly error' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Alerts'].first['Disposition'] = 'This message does not have a key'
        parsed_response_body['Alerts'][1] = parsed_response_body['Alerts'].first
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'only returns one copy of the each error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: ['This message does not have a key'],
        )
        expect(response.exception).to be_nil
      end
    end

    context 'when there are alerts with success result codes' do
      let(:http_response) do
        instance_double(
          Faraday::Response,
          body: {
            Result: 2,
            Alerts: [
              { Result: 1, Disposition: 'The birth date is valid' },
              { Result: 2, Disposition: 'The document type could not be determined' },
            ],
          }.to_json,
        )
      end

      it 'does not return errors for alerts with success result codes' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          # This is the error message for the error in the response fixture
          results: ['The document type could not be determined'],
        )
        expect(response.exception).to be_nil
      end
    end

    context 'when front image HDPI is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'].first['HorizontalResolution'] = 250
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with front DPI error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::DPI_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when front image VDPI is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'].first['VerticalResolution'] = 250
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with front DPI error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::DPI_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when back image HDPI is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][1]['HorizontalResolution'] = 250
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with back DPI error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::DPI_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when back image VDPI is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][1]['VerticalResolution'] = 250
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with back DPI error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::DPI_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when front and back image DPI is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][0]['HorizontalResolution'] = 250
        parsed_response_body['Images'][1]['VerticalResolution'] = 250
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with both DPI error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::DPI_LOW_BOTH_SIDES],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when front image sharpness is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][0]['SharpnessMetric'] = 25
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with front sharpness error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::SHARP_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when back image sharpness is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][1]['SharpnessMetric'] = 25
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with back sharpness error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::SHARP_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when both images sharpness is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][0]['SharpnessMetric'] = 25
        parsed_response_body['Images'][1]['SharpnessMetric'] = 25
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with both sharpness error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::SHARP_LOW_BOTH_SIDES],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when a sharpness metric is missing' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][0].delete('SharpnessMetric')
        parsed_response_body['Images'][1]['SharpnessMetric'] = 25
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with single sharpness error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::SHARP_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when front image glare is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][0]['GlareMetric'] = 25
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with front glare error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::GLARE_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when back image glare is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][1]['GlareMetric'] = 25
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with back glare error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::GLARE_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when both images glare is too low' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][0]['GlareMetric'] = 25
        parsed_response_body['Images'][1]['GlareMetric'] = 25
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with both glare error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::GLARE_LOW_BOTH_SIDES],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end

    context 'when a glare metric is missing' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Images'][0].delete('GlareMetric')
        parsed_response_body['Images'][1]['GlareMetric'] = 25
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with single glare error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          results: [IdentityDocAuth::Errors::GLARE_LOW_ONE_SIDE],
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(IdentityDocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end
  end
end
