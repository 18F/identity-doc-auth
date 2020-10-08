require "bundler/setup"
require "identity-doc-auth"

Dir['spec/support/**/*.rb'].each do |support_path|
  require File.expand_path(support_path)
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
