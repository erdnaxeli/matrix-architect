require "./commands"
require "./connection"
require "./events"

module Matrix::Architect
  module Bot
    def self.run(hs_url, access_token)
      conn = Connection.new(hs_url, access_token)

      first_sync = true
      channel = Channel(Events::Sync).new
      conn.sync(channel)

      loop do
        sync = channel.receive

        sync.invites do |invite|
          begin
            conn.join(invite.room_id)
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
          if (message = event.message?) && event.sender != conn.user_id
            spawn exec_command message, event, conn
          end
        end
      end
    end

    def self.exec_command(message, event, conn)
      begin
        Commands.run message.body, event.room_id, conn
      rescue ex : Exception
        puts %(Error while executing command "message.body")
        puts ex.message
      end
    end
  end
end
