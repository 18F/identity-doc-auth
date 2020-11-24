module LexisNexisFixtures
  def self.true_id_response_success
    load_response_fixture('true_id_response_success.json')
  end

  def self.true_id_response_success_2
    load_response_fixture('true_id_response_success_2.json')
  end

  def self.true_id_response_failure_no_liveness
    load_response_fixture('true_id_response_failure_no_liveness.json')
  end

  def self.true_id_response_failure_with_liveness
    load_response_fixture('true_id_response_failure_with_liveness.json')
  end

  def self.true_id_response_failure_with_all_failures
    load_response_fixture('true_id_response_failure_with_all_failures.json')
  end

  def self.communications_error
    load_response_fixture('communications_error.json')
  end

  def self.internal_application_error
    load_response_fixture('internal_application_error.json')
  end

  def self.load_response_fixture(filename)
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/lexis_nexis_responses',
      filename,
    )
    File.read(path)
  end
end
