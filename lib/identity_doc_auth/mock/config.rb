require 'redacted_struct'

module IdentityDocAuth
  module Mock
    Config = RedactedStruct.new(
      :dpi_threshold,
      :sharpness_threshold,
      :glare_threshold, # required
      keyword_init: true,
      allowed_members: [
        :dpi_threshold,
        :sharpness_threshold,
        :glare_threshold,
      ],
    )
  end
end
