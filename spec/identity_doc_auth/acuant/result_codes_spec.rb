require 'spec_helper'

RSpec.describe IdentityDocAuth::Acuant::ResultCodes do
  describe '.from_int' do
    it 'is a result code for the int' do
      result_code = IdentityDocAuth::Acuant::ResultCodes.from_int(1)
      expect(result_code).to be_a(IdentityDocAuth::Acuant::ResultCodes::ResultCode)
      expect(result_code.billed?).to eq(true)
    end

    it 'is nil when there is no matching code' do
      result_code = IdentityDocAuth::Acuant::ResultCodes.from_int(999)
      expect(result_code).to be_nil
    end
  end
end
