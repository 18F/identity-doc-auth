module IdentityDocAuth
  module CroppingModes
    # No cropping is performed (default).
    NONE = '0'
    # Automatically determine whether cropping is required. Not recommended.
    AUTOMATIC = '1'
    # Cropping is always performed.
    ALWAYS = '3'

    ALL = [
      NONE,
      AUTOMATIC,
      ALWAYS,
    ].freeze
  end
end
