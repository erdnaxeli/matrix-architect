require "http/client"
require "json"

require "./events"
require "./errors"

module Matrix::Architect
  class Connection
    class ExecError < Exception
    end

    getter user_id : String = ""

    def initialize(hs_url : String, access_token : String)
      @access_token = access_token
      @hs_url = hs_url
      @syncing = false
      @tx_id = 0

      puts "Connecting to #{hs_url}"
      @client_sync = HTTP::Client.new(@hs_url, 443, true)
      @user_id = self.whoami

      puts "User's id is #{@user_id}"
    end

    def create_filter(filter) : String
      response = self.post "/user/#{@user_id}/filter", filter
      return response["filter_id"].as_s
    end

    def join(room_id)
      self.post "/rooms/#{room_id}/join"
    end

    def send_message(room_id, message, html = nil)
      tx_id = "#{Time.utc.to_unix_f}.#{@tx_id}"
      data = {
        body:    message,
        msgtype: "m.text",
      }

      if !html.nil?
        data = data.merge(
          {
            format:         "org.matrix.custom.html",
            formatted_body: html,
          }
        )
      end
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
          begin
            if next_batch.nil?
              response = self.get "/sync", is_sync: true, filter: filter_id
            else
              response = self.get "/sync", is_sync: true, filter: filter_id, since: next_batch, timeout: 30_000
            end
          rescue ExecError
            # The sync failed, this is probably due to the HS having
            # difficulties, let's not harm it anymore.
            puts "Error while syncing, waiting 10s before retry"
            sleep 10
            next
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

    private def exec(method, route, is_sync = false, is_admin = false, body = nil, **options)
      params = {} of String => String
      if !options.nil?
        options.each do |k, v|
          params[k.to_s] = v.to_s
        end
      end

      params = HTTP::Params.encode(params)
      if is_admin
        url = "/_synapse/admin#{route}?#{params}"
      else
        url = "/_matrix/client/r0#{route}?#{params}"
      end

      if is_sync
        client = @client_sync
      else
        client = HTTP::Client.new @hs_url, 443, true
      end

      headers = HTTP::Headers{"Authorization" => "Bearer #{@access_token}"}
      if !body.nil?
        body = body.to_json
        headers["Content-Type"] = "application/json"
      end

      puts "#{method} #{url}"
      loop do
        response = client.exec method, url, headers, body

        begin
          case response.status_code
          when 200
            return JSON.parse(response.body)
          when 429
            content = JSON.parse(response.body)
            error = Errors::RateLimited.new(content)
            puts "Rate limited, retry after #{error.retry_after_ms}"
            sleep (error.retry_after_ms + 100).milliseconds
          else
            raise ExecError.new("Invalid status code #{response.status_code}: #{response.body}")
          end
        rescue ex : JSON::ParseException
          puts "Error while parsing JSON: #{ex.message}"
          puts ex.inspect_with_backtrace
          puts "Response body: #{response.body}"
          raise ExecError.new
        end
      end
    end

    def get(route, **options)
      return self.exec "GET", route, **options
    end

    def post(route, data = nil, **options)
      return self.exec "POST", route, **options, body: data
    end

    def put(route, data = nil)
      return self.exec "PUT", route, body: data
    end
  end
end
