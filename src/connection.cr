require "http/client"
require "json"

module Matrix::Architect
  class Connection
    @user_id : String = ""

    def initialize(hs_url : String, access_token : String)
      @access_token = access_token
      @hs_url = hs_url

      puts "Connecting to #{hs_url}"

      @client = HTTP::Client.new(@hs_url, 443, true)
      @user_id = self.whoami

      puts "user id is #{@user_id}"
    end

    def get(route)
      params = HTTP::Params.encode({"access_token" => @access_token})
      response = @client.get "/_matrix/client/r0#{route}?#{params}"

      if response.status_code != 200
        raise Exception.new("Not 200 OK")
      end

      return JSON.parse(response.body)
    end

    def join(room_id)
    end

    def whoami
      response = self.get("/account/whoami")
      return response["user_id"].as_s
    end
  end
end
