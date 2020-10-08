module DocAuthImageFixtures
  module_function

  def document_front_image
    load_image_data('id-front.jpg')
  end

  def document_front_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('id-front.jpg'), 'image/jpeg')
  end

  def document_front_image_data_url
    "data:image/jpeg,#{CGI.escape(document_front_image)}"
  end

  def document_back_image
    load_image_data('id-back.jpg')
  end

  def document_back_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('id-back.jpg'), 'image/jpeg')
  end

  def document_back_image_data_url
    "data:image/jpeg,#{CGI.escape(document_back_image)}"
  end

  def document_face_image
    load_image_data('id-face.jpg')
  end

  def document_face_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('id-face.jpg'), 'image/jpeg')
  end

  def selfie_image
    load_image_data('selfie.jpg')
  end

  def selfie_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('selfie.jpg'), 'image/jpeg')
  end

  def selfie_image_data_url
    "data:image/jpeg,#{CGI.escape(selfie_image)}"
  end

  def error_yaml_multipart
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/ial2_test_credential_forces_error.yml',
    )
    Rack::Test::UploadedFile.new(path, Mime[:yaml])
  end

  def fixture_path(filename)
    File.join(
      File.dirname(__FILE__),
      '../fixtures/doc_auth_images',
      filename,
    )
  end

  def load_image_data(filename)
    File.read(fixture_path(filename))
  end
end
