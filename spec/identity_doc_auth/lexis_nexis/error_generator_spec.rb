require 'spec_helper'

RSpec.describe IdentityDocAuth::LexisNexis::ErrorGenerator do

  let(:exception_notifier) { instance_double('Proc') }

  let(:i18n) do
    FakeI18n.new(
      'doc_auth.errors.lexis_nexis.barcode_content_check',
      'doc_auth.errors.lexis_nexis.barcode_read_check',
      'doc_auth.errors.lexis_nexis.birth_date_checks',
      'doc_auth.errors.lexis_nexis.control_number_check',
      'doc_auth.errors.lexis_nexis.expiration_checks',
      'doc_auth.errors.lexis_nexis.full_name_check',
      'doc_auth.errors.lexis_nexis.general_error_no_liveness',
      'doc_auth.errors.lexis_nexis.general_error_liveness',
      'doc_auth.errors.lexis_nexis.id_not_verified',
      'doc_auth.errors.lexis_nexis.multiple_back_id_failures',
      'doc_auth.errors.lexis_nexis.ref_control_number_check',
      'doc_auth.errors.lexis_nexis.selfie_failure',
      )
  end
  let(:config) do
    IdentityDocAuth::LexisNexis::Config.new(
      i18n: i18n,
      exception_notifier: exception_notifier,
    )
  end

  def build_alerts(*failed)
    {
      passed: [],
      failed: failed,
    }
  end

  def build_error_info (doc_auth_result, alerts, pm_result)
    {
      ConversationId: 31000406181234,
      Reference: 'Reference1',
      LivenessChecking: 'test',
      ProductType: 'TrueID',
      TransactionReasonCode: 'testing',
      DocAuthResult: doc_auth_result,
      Alerts: alerts,
      AlertFailureCount: alerts[:failed].length,
      PortraitMatchResults: { FaceMatchResult: pm_result },
      ImageMetrics: {},
    }
  end

  context 'The correct errors are delivered with liveness off when' do
    it 'DocAuthResult is Attention' do
      error_info = build_error_info(
        'Attention',
        build_alerts({name: '2D Barcode Read', result: 'Attention'}),
        nil)

      output = described_class.new(config).generate_trueid_errors(error_info, false)

      expect(output.keys).to contain_exactly(:back)
      expect(output[:back]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.barcode_read_check')
      )
    end

    it 'DocAuthResult is Failed' do
      error_info = build_error_info(
        'Failed',
        build_alerts({name: 'Visible Pattern', result: 'Failed'}),
        nil)

      output = described_class.new(config).generate_trueid_errors(error_info, false)

      expect(output.keys).to contain_exactly(:id)
      expect(output[:id]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.id_not_verified')
      )
    end

    it 'DocAuthResult is Failed with multiple different alerts' do
      error_info = build_error_info(
        'Failed',
        build_alerts({name: '2D Barcode Read', result: 'Attention'},
                     {name: 'Visible Pattern', result: 'Failed'}),
        nil)

      output = described_class.new(config).generate_trueid_errors(error_info, false)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
      )
    end

    it 'DocAuthResult is Failed with multiple id alerts' do
      error_info = build_error_info(
        'Failed',
        build_alerts({name: 'Expiration Date Valid', result: 'Attention'},
                     {name: 'Full Name Crosscheck', result: 'Failed'}),
        nil)

      output = described_class.new(config).generate_trueid_errors(error_info, false)

      expect(output.keys).to contain_exactly(:id)
      expect(output[:id]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
      )
    end

    it 'DocAuthResult is Failed with multiple back alerts' do
      error_info = build_error_info(
        'Failed',
        build_alerts({name: '2D Barcode Read', result: 'Attention'},
                     {name: '2D Barcode Content', result: 'Failed'}),
        nil)

      output = described_class.new(config).generate_trueid_errors(error_info, false)

      expect(output.keys).to contain_exactly(:back)
      expect(output[:back]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.multiple_back_id_failures')
      )
    end

    it 'DocAuthResult is Failed with an unknown alert' do
      error_info = build_error_info(
        'Failed',
        build_alerts({name: 'Not a known alert', result: 'Failed'}),
        nil)

      expect(exception_notifier).to receive(:call).
        with(anything, hash_including(:response_info)).twice

      output = described_class.new(config).generate_trueid_errors(error_info, false)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
      )
    end

    it 'DocAuthResult is Failed with multiple alerts including an unknown' do
      error_info = build_error_info(
        'Failed',
        build_alerts({name: 'Not a known alert', result: 'Failed'},
                     {name: 'Birth Date Crosscheck', result: 'Failed'}),
        nil)

      expect(exception_notifier).to receive(:call).
        with(anything, hash_including(:response_info)).once

      output = described_class.new(config).generate_trueid_errors(error_info, false)

      expect(output.keys).to contain_exactly(:id)
      expect(output[:id]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.birth_date_checks')
      )
    end

    it 'DocAuthResult is Failed with an unknown passed alert' do
      error_info = build_error_info(
        'Failed',
        { passed: [{name: 'Not a known alert', result: 'Passed'}],
          failed: [{name: 'Birth Date Crosscheck', result: 'Failed'}] },
        nil)

      expect(exception_notifier).to receive(:call).
        with(anything, hash_including(:response_info)).once

      output = described_class.new(config).generate_trueid_errors(error_info, false)

      expect(output.keys).to contain_exactly(:id)
      expect(output[:id]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.birth_date_checks')
      )
    end
  end

  context 'The correct errors are delivered with liveness on when' do
    it 'DocAuthResult is Attention and selfie has passed' do
      error_info = build_error_info(
        'Attention',
        build_alerts({name: '2D Barcode Read', result: 'Attention'}),
        'Pass')

      output = described_class.new(config).generate_trueid_errors(error_info, true)

      expect(output.keys).to contain_exactly(:back)
      expect(output[:back]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.barcode_read_check')
      )
    end

    it 'DocAuthResult is Attention and selfie has failed' do
      error_info = build_error_info(
        'Attention',
        build_alerts({name: '2D Barcode Read', result: 'Attention'}),
        'Fail')

      output = described_class.new(config).generate_trueid_errors(error_info, true)

      expect(output.keys).to contain_exactly(:general)
      expect(output[:general]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.general_error_liveness')
      )
    end

    it 'DocAuthResult is Attention and selfie has succeeded' do
      error_info = build_error_info(
        'Attention',
        build_alerts({name: '2D Barcode Read', result: 'Attention'}), 'Pass')

      output = described_class.new(config).generate_trueid_errors(error_info, true)

      expect(output.keys).to contain_exactly(:back)
      expect(output[:back]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.barcode_read_check')
      )
    end

    it 'DocAuthResult has passed but liveness failed' do
      error_info = build_error_info('Passed', build_alerts(), 'Fail')

      output = described_class.new(config).generate_trueid_errors(error_info, true)

      expect(output.keys).to contain_exactly(:selfie)
      expect(output[:selfie]).to contain_exactly(
        i18n.t('doc_auth.errors.lexis_nexis.selfie_failure')
      )
    end
  end
end
