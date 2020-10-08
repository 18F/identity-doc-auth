module IdentityDocAuth
  module Acuant
    module Requests
      class GetFaceImageRequest < IdentityDocAuth::Acuant::Request
        attr_reader :instance_id

        def initialize(instance_id:)
          @instance_id = instance_id
        end

        def path
          "/AssureIDService/Document/#{instance_id}/Field/Image?key=Photo"
        end

        def handle_http_response(http_response)
          IdentityDocAuth::Acuant::Responses::GetFaceImageResponse.new(http_response)
        end

        def method
          :get
        end
      end
    end
  end
end
