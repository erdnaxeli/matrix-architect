require "./connection"
require "./events"

module Matrix::Architect
  module Bot
    def self.run(hs_url, access_token)
      conn = Connection.new(hs_url, access_token)

      channel = Channel(Events::Sync).new
      conn.sync(channel)

      loop do
        sync = channel.receive

        sync.invites do |invite|
          conn.join(invite.room_id)
        end

        sync.room_events do |event|
          if (message = event.message?) && event.sender != conn.user_id
            conn.send_message event.room_id, message.body
          end
        end
      end
    end
  end
end
