require "./connection"
require "./events"

module Matrix::Architect
  module Bot
    def self.run(hs_url, access_token)
      conn = Connection.new(hs_url, access_token)

      channel = Channel(Events::Sync).new
      conn.sync(channel)

      loop do
        event = channel.receive

        event.invites do |invite|
          conn.join(invite.room_id)
        end
      end
    end
  end
end
