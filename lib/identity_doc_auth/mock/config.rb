require 'redacted_struct'

module IdentityDocAuth
  module Mock
    # @!attribute [rw] exception_notifier
    #   @return [Proc] should be a proc that accepts an Exception and an optional context hash
    #   @example
    #      config.exception_notifier.call(RuntimeError.new("oh no"), attempt_count: 1)
    Config = RedactedStruct.new(
      :exception_notifier,
      :dpi_threshold,
      :sharpness_threshold,
      :glare_threshold, # required
      keyword_init: true,
      allowed_members: [
        :exception_notifier,
        :dpi_threshold,
        :sharpness_threshold,
        :glare_threshold,
      ],
    ) do
      def validate!
        raise 'config missing base_url' if !base_url
        raise 'config missing locale' if !locale
      end
    end
  end
end
