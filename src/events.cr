require "json"

module Matrix::Architect
  module Events
    class Invite
      getter room_id : String

      def initialize(room_id, payload : JSON::Any)
        @room_id = room_id
        @payload = payload
      end
    end

    class Sync
      def initialize(payload : JSON::Any)
        @payload = payload

        puts payload
      end

      def invites(&block)
        @payload["rooms"]["invite"].as_h.each do |room_id, invite|
          yield Invite.new(room_id, invite)
        end
      end
    end
  end
end
