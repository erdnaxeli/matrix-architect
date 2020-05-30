require "http/client"
require "json"

require "./events"

module Matrix::Architect
  class Connection
    @user_id : String = ""

    def initialize(hs_url : String, access_token : String)
      @access_token = access_token
      @hs_url = hs_url
      @syncing = false

      puts "Connecting to #{hs_url}"

      @client = HTTP::Client.new(@hs_url, 443, true)
      @client_sync = HTTP::Client.new(@hs_url, 443, true)
      @user_id = self.whoami
      # we use a separated client to sync as it will run in his own Fiber

      puts "User's id is #{@user_id}"
    end

    def create_filter(filter) : String
      response = self.post("/user/#{@user_id}/filter", filter)
      return response["filter_id"].as_s
    end

    def join(room_id)
      self.post "/rooms/#{room_id}/join"
    end

    def sync(channel)
      if @syncing
        raise Exception.new("Already syncing")
      end

      # create filter to use for sync
      filter = {
        account_data: {types: [] of String},
        presence:     {types: [] of String},
        room:         {
          account_data: {types: [] of String},
          ephemeral:    {types: [] of String},
          timeline:     {lazy_load_members: true},
          state:        {lazy_load_members: true},
        },
      }.to_json
      filter_id = self.create_filter filter

      spawn do
        next_batch = nil

        loop do
          if next_batch.nil?
            response = self.get "/sync", is_sync: true, filter: filter_id
          else
            response = self.get "/sync", is_sync: true, filter: filter_id, since: next_batch, timeout: 30000
          end

          next_batch = response["next_batch"]?.try &.to_s
          channel.send(Events::Sync.new(response))
        end
      end
    end

    def whoami : String
      response = self.get("/account/whoami")
      return response["user_id"].as_s
    end

    private def get(route, is_sync = false, **options)
      params = {"access_token" => @access_token}
      if !options.nil?
        options.each do |k, v|
          params[k.to_s] = v.to_s
        end
      end

      params = HTTP::Params.encode(params)
      url = "/_matrix/client/r0#{route}?#{params}"
      puts "GET #{url}"

      if is_sync
        puts "Is sync"
        response = @client_sync.get url
      else
        response = @client.get url
      end

      if response.status_code != 200
        raise Exception.new("Invalid status code #{response.status_code}")
      end

      return JSON.parse(response.body)
    end


    private def post(route, data = nil)
      params = HTTP::Params.encode({"access_token" => @access_token})
      url = "/_matrix/client/r0#{route}?#{params}"

      puts "POST #{url}"
      response = @client.post url, HTTP::Headers{"Content-Type" => "application/json"}, data

      if response.status_code != 200
        raise Exception.new("Invalid status code #{response.status_code}: #{response.body}")
      end

      return JSON.parse(response.body)
    end
  end
end
