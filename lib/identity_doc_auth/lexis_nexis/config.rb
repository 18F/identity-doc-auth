module IdentityDocAuth
  module LexisNexis
    # @!attribute [rw] exception_notifier
    #   @return [Proc] should be a proc that accepts an Exception and an optional context hash
    #   @example
    #      config.exception_notifier.call(RuntimeError.new("oh no"), attempt_count: 1)
    Config = Struct.new(
      :account_id,
      :base_url, # required
      :request_mode,
      :trueid_account_id,
      :trueid_liveness_workflow,
      :trueid_noliveness_workflow,
      :trueid_password,
      :trueid_username,
      :timeout, # optional
      :exception_notifier, # optional
      :locale, # required
      keyword_init: true,
    ) do
      def validate!
        raise 'config missing base_url' if !base_url
        raise 'config missing locale' if !locale
      end
    end
  end
end
