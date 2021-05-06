require 'spec_helper'

RSpec.describe IdentityDocAuth::ErrorGenerator do

  let(:exception_notifier) { instance_double('Proc') }

  let(:config) do
    IdentityDocAuth::LexisNexis::Config.new(
      exception_notifier: exception_notifier,
    )
  end

  def build_error_info(
    doc_result: nil,
    passed: [],
    failed: [],
    liveness_result: nil,
    image_metrics: {}
  )
    {
      conversation_id: 31000406181234,
      reference: 'Reference1',
      liveness_enabled: liveness_result.present? ? true : false,
      vendor: 'Test',
      transaction_reason_code: 'testing',
      doc_auth_result: doc_result,
      processed_alerts: {
        passed: passed,
        failed: failed,
      },
      alert_failure_count: failed.length,
      portrait_match_results: { FaceMatchResult: liveness_result },
      image_metrics: image_metrics,
    }
  end

  context 'The correct errors are delivered with liveness off when' do
    it 'DocAuthResult is Attention' do
      error_info = build_error_info(
        doc_result: 'Attention',
        failed: [{ name: '2D Barcode Read', result: 'Attention' }]
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:back)
      expect(output[:back]).to contain_exactly(IdentityDocAuth::Errors::BARCODE_READ_CHECK)
    end

    it 'DocAuthResult is Failed' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [{ name: 'Visible Pattern', result: 'Failed' }]
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:id)
      expect(output[:id]).to contain_exactly(IdentityDocAuth::Errors::ID_NOT_VERIFIED)
    end

    it 'DocAuthResult is Failed with multiple different alerts' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          {name: '2D Barcode Read', result: 'Attention'},
          {name: 'Visible Pattern', result: 'Failed'},
        ]
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::GENERAL_ERROR_NO_LIVENESS)
    end

    it 'DocAuthResult is Failed with multiple id alerts' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          {name: 'Expiration Date Valid', result: 'Attention'},
          {name: 'Full Name Crosscheck', result: 'Failed'},
        ]
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:id)
      expect(output[:id]).to contain_exactly(IdentityDocAuth::Errors::GENERAL_ERROR_NO_LIVENESS)
    end

    it 'DocAuthResult is Failed with multiple back alerts' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          {name: '2D Barcode Read', result: 'Attention'},
          {name: '2D Barcode Content', result: 'Failed'},
        ]
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:back)
      expect(output[:back]).to contain_exactly(IdentityDocAuth::Errors::MULTIPLE_BACK_ID_FAILURES)
    end

    it 'DocAuthResult is Failed with an unknown alert' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [{ name: 'Not a known alert', result: 'Failed' }]
      )

      expect(exception_notifier).to receive(:call).
        with(anything, hash_including(:response_info)).twice

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::GENERAL_ERROR_NO_LIVENESS)
    end

    it 'DocAuthResult is Failed with multiple alerts including an unknown' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          { name: 'Not a known alert', result: 'Failed' },
          { name: 'Birth Date Crosscheck', result: 'Failed' },
        ]
      )

      expect(exception_notifier).to receive(:call).
        with(anything, hash_including(:response_info)).once

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:id)
      expect(output[:id]).to contain_exactly(IdentityDocAuth::Errors::BIRTH_DATE_CHECKS)
    end

    it 'DocAuthResult is Failed with an unknown passed alert' do
      error_info = build_error_info(
        doc_result: 'Failed',
        passed: [{ name: 'Not a known alert', result: 'Passed' }],
        failed: [{ name: 'Birth Date Crosscheck', result: 'Failed' }],
      )

      expect(exception_notifier).to receive(:call).
        with(anything, hash_including(:response_info)).once

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:id)
      expect(output[:id]).to contain_exactly(IdentityDocAuth::Errors::BIRTH_DATE_CHECKS)
    end
  end

  context 'The correct errors are delivered with liveness on when' do
    it 'DocAuthResult is Attention and selfie has passed' do
      error_info = build_error_info(
        doc_result: 'Attention',
        liveness_result: 'Pass',
        failed: [{ name: '2D Barcode Read', result: 'Attention' }]
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:back)
      expect(output[:back]).to contain_exactly(IdentityDocAuth::Errors::BARCODE_READ_CHECK)
    end

    it 'DocAuthResult is Attention and selfie has failed' do
      error_info = build_error_info(
        doc_result: 'Attention',
        liveness_result: 'Fail',
        failed: [{ name: '2D Barcode Read', result: 'Attention' }]
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::GENERAL_ERROR_LIVENESS)
    end

    it 'DocAuthResult is Attention and selfie has succeeded' do
      error_info = build_error_info(
        doc_result: 'Attention',
        liveness_result: 'Pass',
        failed: [{ name: '2D Barcode Read', result: 'Attention' }]
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:back)
      expect(output[:back]).to contain_exactly(IdentityDocAuth::Errors::BARCODE_READ_CHECK)
    end

    it 'DocAuthResult has passed but liveness failed' do
      error_info = build_error_info(doc_result: 'Passed', liveness_result: 'Fail')

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:selfie)
      expect(output[:selfie]).to contain_exactly(IdentityDocAuth::Errors::SELFIE_FAILURE)
    end
  end

  context 'The correct errors are delivered for image metrics when' do
    let(:metrics) {
      {
        front: {
          'HorizontalResolution' => 300,
          'VerticalResolution' => 300,
          'SharpnessMetric' => 50,
          'GlareMetric' => 50,
        },
        back: {
          'HorizontalResolution' => 300,
          'VerticalResolution' => 300,
          'SharpnessMetric' => 50,
          'GlareMetric' => 50,
        }
      }
    }

    it 'front image HDPI is too low' do
      metrics[:front]['HorizontalResolution'] = 250
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::DPI_LOW_ONE_SIDE)
    end

    it 'front image VDPI is too low' do
      metrics[:front]['VerticalResolution'] = 250
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::DPI_LOW_ONE_SIDE)
    end

    it 'back image HDPI is too low' do
      metrics[:back]['HorizontalResolution'] = 250
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::DPI_LOW_ONE_SIDE)
    end

    it 'front and back image DPI is too low' do
      metrics[:front]['HorizontalResolution'] = 250
      metrics[:back]['VerticalResolution'] = 250
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::DPI_LOW_BOTH_SIDES)
    end

    it 'front image sharpness is too low' do
      metrics[:front]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::SHARP_LOW_ONE_SIDE)
    end

    it 'back image sharpness is too low' do
      metrics[:back]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::SHARP_LOW_ONE_SIDE)
    end

    it 'both images sharpness is too low' do
      metrics[:front]['SharpnessMetric'] = 25
      metrics[:back]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::SHARP_LOW_BOTH_SIDES)
    end

    it 'both images sharpness is too low' do
      metrics[:front].delete('SharpnessMetric')
      metrics[:back]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::SHARP_LOW_ONE_SIDE)
    end

    it 'front image glare is too low' do
      metrics[:front]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::GLARE_LOW_ONE_SIDE)
    end

    it 'back image glare is too low' do
      metrics[:back]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::GLARE_LOW_ONE_SIDE)
    end

    it 'front image glare is too low' do
      metrics[:back]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::GLARE_LOW_ONE_SIDE)
    end

    it 'both images sharpness is too low' do
      metrics[:front]['GlareMetric'] = 25
      metrics[:back]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::GLARE_LOW_BOTH_SIDES)
    end

    it 'both images sharpness is too low' do
      metrics[:front].delete('GlareMetric')
      metrics[:back]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(IdentityDocAuth::Errors::GLARE_LOW_ONE_SIDE)
    end
  end
end
