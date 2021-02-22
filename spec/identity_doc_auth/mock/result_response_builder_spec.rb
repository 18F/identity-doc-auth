require 'spec_helper'

RSpec.describe IdentityDocAuth::Mock::ResultResponseBuilder do
  describe '#call' do
    subject(:builder) { described_class.new(input) }

    context 'with an image file' do
      let(:input) { DocAuthImageFixtures.document_front_image }

      it 'returns a successful response with the default PII' do
        response = builder.call

        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.exception).to eq(nil)
        expect(response.pii_from_doc).
          to eq(IdentityDocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC)
      end
    end

    context 'with a yaml file containing PII' do
      let(:input) do
        <<~YAML
          document:
            first_name: Susan
            last_name: Smith
            middle_name: Q
            address1: 1 Microsoft Way
            address2: Apt 3
            city: Bayside
            state: NY
            zipcode: '11364'
            dob: 10/06/1938
            state_id_number: '111111111'
            state_id_jurisdiction: ND
            state_id_type: drivers_license
        YAML
      end

      it 'returns a result with that PII' do
        response = builder.call

        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.exception).to eq(nil)
        expect(response.pii_from_doc).to eq(
          first_name: 'Susan',
          middle_name: 'Q',
          last_name: 'Smith',
          address1: '1 Microsoft Way',
          address2: 'Apt 3',
          city: 'Bayside',
          state: 'NY',
          zipcode: '11364',
          dob: '10/06/1938',
          state_id_number: '111111111',
          state_id_jurisdiction: 'ND',
          state_id_type: 'drivers_license',
        )
      end
    end

    context 'with a yaml file containing an error' do
      let(:input) do
        <<~YAML
          friendly_error: This is a test error
        YAML
      end

      it 'returns a result with that error' do
        response = builder.call

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(results: ['This is a test error'])
        expect(response.exception).to eq(nil)
        expect(response.pii_from_doc).to eq({})
      end
    end

    context 'with a data URI' do
      let(:input) do
        <<~STR
          data:image/gif;base64,R0lGODlhyAAiALM...DfD0QAADs=
        STR
      end

      it 'returns a successful response with the default PII' do
        response = builder.call

        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.exception).to eq(nil)
        expect(response.pii_from_doc).
          to eq(IdentityDocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC)
      end
    end

    context 'with URI that is not a data URI' do
      let(:input) do
        <<~STR
          https://example.com
        STR
      end

      it 'returns an error response that explains it should have been a data URI' do
        response = builder.call

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(results: ['parsed URI, but scheme was https (expected data)'])
        expect(response.exception).to eq(nil)
        expect(response.pii_from_doc).to eq({})
      end
    end

    context 'with string data that is not a URI or a hash' do
      let(:input) do
        <<~STR
          something that is definitely not a URI
        STR
      end

      it 'returns an error response that explains it should have been a hash' do
        response = builder.call

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(results: ['YAML data should have been a hash, got String'])
        expect(response.exception).to eq(nil)
        expect(response.pii_from_doc).to eq({})
      end
    end
  end
end
