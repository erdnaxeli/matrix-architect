require "option_parser"

require "../connection"

module Matrix::Architect
  module Commands
    class Room
      enum Order
        StateEvents

        def to_s
          case self
          when Order::StateEvents
            "state_events"
          else
            "unknown"
          end
        end
      end

      def initialize(@room_id : String, @conn : Connection)
      end

      def self.run(args, room_id, conn)
        Room.new(room_id, conn).run args
      end

      def self.usage(str)
        str << "\
!room details ROOM_ID
Get all details about a room.

!room top-complexity
Get top 10 rooms in complexity, aka state events number.

!room top-members
Get top 10 rooms in number of members.

!room purge ROOM_ID
Remove all trace of a room from your database.
All local users must have left the room before.
"
      end

      def run(args) : Nil
        command = args.shift?
        case command
        when "details"
          details args
        when "top-complexity"
          complexity
        when "top-members"
          members
        when "purge"
          purge args
        else
          @conn.send_message @room_id, "Unknown command"
        end
      end

      private def build_rooms_list(rooms, key, is_html = false)
        String.build do |str|
          if is_html
            str << "<ul>"
          end
          rooms.each do |room|
            if is_html
              str << "<li>"
            else
              str << "* "
            end

            if name = room["name"].as_s?
              str << name << " "
            end

            if canonical_alias = room["canonical_alias"].as_s?
              str << canonical_alias << " "
            end

            str << room["room_id"].as_s << " " << room[key] << "\n"

            if is_html
              str << "</li>"
            end
          end

          if is_html
            str << "</ul>"
          end
        end
      end

      private def complexity : Nil
        begin
          rooms = get_rooms Order::StateEvents
        rescue ex : Connection::ExecError
          @conn.send_message @room_id, "Error: #{ex.message}"
        else
          msg = build_rooms_list rooms[0, 10], Order::StateEvents.to_s
          html = build_rooms_list rooms[0, 10], Order::StateEvents.to_s, is_html: true
          @conn.send_message @room_id, msg, html
        end
      end

      private def details(args) : Nil
        room_id = args.pop?
        if room_id.nil?
          @conn.send_message @room_id, "Usage: !room details ROOM_ID"
          return
        end

        begin
          response = @conn.get "/v1/rooms/#{room_id}", is_admin: true
        rescue ex : Connection::ExecError
          @conn.send_message @room_id, "Error: #{ex.message}"
        else
          msg = response.to_pretty_json
          @conn.send_message @room_id, "```\n#{msg}\n```", "<pre>#{msg}</pre>"
        end
      end

      private def get_rooms(order, limit = 0)
        response = @conn.get "/v1/rooms", is_admin: true, order_by: order
        rooms = response["rooms"].as_a

        while (limit == 0 || rooms.size <= limit) && (next_batch = !response["next_batch"]?)
          response = @conn.get "/v1/rooms", is_admin: true, order_by: order, from: next_batch
          rooms.concat response["rooms"].as_a
        end

        return rooms
      end

      private def members : Nil
      end

      private def purge(args)
        room_id = args.pop?
        if room_id.nil?
          @conn.send_message @room_id, "Usage: !room purge ROOM_ID"
        end

        @conn.send_message @room_id, "Purge starting, depending on the size of the room it may take a while"
        begin
          @conn.post "/v1/purge_room", is_admin: true, data: {room_id: room_id}
        rescue ex : Connection::ExecError
          @conn.send_message @room_id, "Error: #{ex.message}"
        else
          @conn.send_message @room_id, "Purge done"
        end
      end
    end
  end
end
