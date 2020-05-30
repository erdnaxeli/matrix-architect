require "http/client"
require "json"

require "./events"
require "./errors"

module Matrix::Architect
  class Connection
    getter user_id : String = ""

    def initialize(hs_url : String, access_token : String)
      @access_token = access_token
      @hs_url = hs_url
      @syncing = false
      @tx_id = 0

      puts "Connecting to #{hs_url}"
      @client = HTTP::Client.new(@hs_url, 443, true)
      @client_sync = HTTP::Client.new(@hs_url, 443, true)
      @user_id = self.whoami
      # we use a separated client to sync as it will run in his own Fiber

      puts "User's id is #{@user_id}"
    end

    def create_filter(filter) : String
      response = self.post "/user/#{@user_id}/filter", filter
      return response["filter_id"].as_s
    end

    def join(room_id)
      self.post "/rooms/#{room_id}/join"
    end

    def send_message(room_id, message)
      tx_id = "#{Time.utc.to_unix_f}.#{@tx_id}"
      data = {msgtype: "m.text", body: message}
      self.put "/rooms/#{room_id}/send/m.room.message/#{tx_id}", data

      @tx_id += 1
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
      }
      filter_id = self.create_filter filter

      spawn do
        next_batch = nil

        loop do
          if next_batch.nil?
            response = self.get "/sync", is_sync: true, filter: filter_id
          else
            response = self.get "/sync", is_sync: true, filter: filter_id, since: next_batch, timeout: 30_000
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

    private def exec(method, route, is_sync = false, body = nil, **options)
      params = {"access_token" => @access_token}
      if !options.nil?
        options.each do |k, v|
          params[k.to_s] = v.to_s
        end
      end

      params = HTTP::Params.encode(params)
      url = "/_matrix/client/r0#{route}?#{params}"

      if is_sync
        client = @client_sync
      else
        client = @client
      end

      if body.nil?
        headers = nil
      else
        body = body.to_json
        headers = HTTP::Headers{"Content-Type" => "application/json"}
      end

      puts "#{method} #{url}"
      loop do
        response = client.exec method, url, headers, body

        case response.status_code
        when 200
          return JSON.parse(response.body)
        when 429
          content = JSON.parse(response.body)
          error = Errors::RateLimited.new(content)
          puts "Rate limited, retry after #{error.retry_after_ms}"
          sleep (error.retry_after_ms + 100).milliseconds
        else
          raise Exception.new("Invalid status code #{response.status_code}: #{response.body}")
        end
      end
    end

    private def get(route, **options)
      return self.exec "GET", route, **options
    end

    private def post(route, data = nil)
      return self.exec "POST", route, body: data
    end

    private def put(route, data = nil)
      return self.exec "PUT", route, body: data
    end
  end
end
