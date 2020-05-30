require "json"

module Matrix::Architect
  module Events
    struct Invite
      getter room_id : String

      def initialize(room_id, payload : JSON::Any)
        @room_id = room_id
        @payload = payload
      end
    end

    struct Message
      getter body : String

      def initialize(@payload : JSON::Any)
        @body = @payload["content"]["body"].as_s
      end
    end

    struct RoomEvent
      getter room_id : String
      getter sender : String

      def initialize(@room_id, @payload : JSON::Any)
        @sender = @payload["sender"].as_s
      end

      def message?
        if @payload["type"] == "m.room.message"
          return Message.new(@payload)
        end
      end
    end

    struct Sync
      def initialize(payload : JSON::Any)
        @payload = payload

        puts payload
      end

      def invites(&block)
        @payload["rooms"]["invite"].as_h.each do |room_id, invite|
          yield Invite.new(room_id, invite)
        end
      end

      def room_events(&block)
        @payload["rooms"]["join"].as_h.each do |room_id, room|
          room["timeline"]["events"].as_a.each do |event|
            yield RoomEvent.new(room_id, event)
          end
        end
      end
    end
  end
end
