require "http/client"
require "json"

require "./events"
require "./errors"

module Matrix::Architect
  class Connection
    Log = Matrix::Architect::Log.for(self)

    class ExecError < Exception
    end

    getter user_id : String = ""

    def initialize(hs_url : String, access_token : String)
      @access_token = access_token
      @hs_url = hs_url
      @syncing = false
      @tx_id = 0

      Log.info { "Connecting to #{hs_url}" }
      @client_sync = HTTP::Client.new(@hs_url, 443, true)
      @user_id = whoami

      Log.info { "User's id is #{@user_id}" }
    end

    def create_filter(filter) : String
      response = post "/user/#{@user_id}/filter", filter
      return response["filter_id"].as_s
    end

    def join(room_id)
      post "/rooms/#{room_id}/join"
    end

    def edit_message(room_id : String, event_id : String, message : String, html : String? = nil) : Nil
      tx_id = get_tx_id
      new_content = get_message_content(message, html)
      data = new_content.merge(
        {
          "m.new_content": new_content,
          "m.relates_to":  {
            rel_type: "m.replace",
            event_id: event_id,
          },
        }
      )
      response = put "/rooms/#{room_id}/send/m.room.message/#{tx_id}", data
    end

    def send_message(room_id : String, message : String, html : String? = nil) : String
      tx_id = get_tx_id
      data = get_message_content(message, html)
      response = put "/rooms/#{room_id}/send/m.room.message/#{tx_id}", data

      return response["event_id"].as_s
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
      filter_id = create_filter filter

      spawn do
        next_batch = nil

        loop do
          begin
            if next_batch.nil?
              response = get "/sync", is_sync: true, filter: filter_id
            else
              response = get "/sync", is_sync: true, filter: filter_id, since: next_batch, timeout: 300_000
            end
          rescue ex : ExecError
            # The sync failed, this is probably due to the HS having
            # difficulties, let's not harm it anymore.
            Log.error(exception: ex) { "Error while syncing, waiting 10s before retry" }
            sleep 10
            next
          end

          next_batch = response["next_batch"]?.try &.to_s
          channel.send(Events::Sync.new(response))
        end
      end
    end

    def whoami : String
      response = get "/account/whoami"
      return response["user_id"].as_s
    end

    def get(route, **options)
      return exec "GET", route, **options
    end

    def post(route, data = nil, **options)
      return exec "POST", route, **options, body: data
    end

    def put(route, data = nil)
      return exec "PUT", route, body: data
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

      Log.debug { "#{method} #{url}" }
      loop do
        response = client.exec method, url, headers, body

        begin
          case response.status_code
          when 200
            return JSON.parse(response.body)
          when 429
            content = JSON.parse(response.body)
            error = Errors::RateLimited.new(content)
            Log.warn { "Rate limited, retry after #{error.retry_after_ms}" }
            sleep (error.retry_after_ms + 100).milliseconds
          else
            raise ExecError.new("Invalid status code #{response.status_code}: #{response.body}")
          end
        rescue ex : JSON::ParseException
          Log.error(exception: ex) { "Error while parsing JSON" }
          Log.error { "Response body: #{response.body}" }
          raise ExecError.new
        end
      end
    end

    private def get_message_content(message : String, html : String? = nil) : NamedTuple
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

      return data
    end

    private def get_tx_id : String
      @tx_id += 1
      return "#{Time.utc.to_unix_f}.#{@tx_id}"
    end
  end
end
