require "./commands"
require "./connection"
require "./events"

module Matrix::Architect
  class Bot
    def initialize(@config : Config)
      @conn = Connection.new(@config.hs_url, @config.access_token)
    end

    def run() : Nil
      first_sync = true
      channel = Channel(Events::Sync).new
      @conn.sync(channel)

      loop do
        sync = channel.receive

        sync.invites do |invite|
          begin
            @conn.join(invite.room_id)
          rescue Connection::ExecError
          end
        end

        if first_sync
          # Ignore the first sync's messages as it can contains events already
          # seen.
          first_sync = false
          next
        end

        sync.room_events do |event|
          if (message = event.message?) && event.sender != @conn.user_id && @config.users_id.includes? event.sender
            spawn exec_command message, event
          end
        end
      end
    end

    def exec_command(message, event) : Nil
      begin
        Commands.run message.body, event.room_id, @conn
      rescue ex : Exception
        puts %(Error while executing command "message.body")
        puts ex.message
      end
    end
  end
end
