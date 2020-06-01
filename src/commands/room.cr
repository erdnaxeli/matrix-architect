require "option_parser"

require "../connection"

module Matrix::Architect
  module Commands
    class Room
      enum Order
        JoinedLocalMembers
        JoinedMembers
        Name
        StateEvents

        def to_s
          super.underscore
        end
      end

      def initialize(@room_id : String, @conn : Connection)
      end

      def self.run(args, room_id, conn)
        Room.new(room_id, conn).run args
      end

      def self.usage(str)
        str << "\

!room count
Return the total count of rooms.

!room details ROOM_ID
Get all details about a room.

!room garbage-collect
Purge all rooms without any local users joined.

!room top-complexity
Get top 10 rooms in complexity, aka state events number.

!room top-members
Get top 10 rooms in number of members.

!room top-local-members
Get top 10 rooms in number of local members.

!room purge ROOM_ID
Remove all trace of a room from your database.
All local users must have left the room before.
"
      end

      def run(args) : Nil
        command = args.shift?
        case command
        when "count"
          count
        when "details"
          details args
        when "garbage-collect"
          garbage_collect
        when "top-complexity"
          top_rooms Order::StateEvents
        when "top-local-members"
          top_rooms Order::JoinedLocalMembers
        when "top-members"
          top_rooms Order::JoinedMembers
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

      private def count
        begin
          rooms = get_rooms limit: 0
        rescue ex : Connection::ExecError
          @conn.send_message @room_id, "Error: #{ex.message}"
        else
          @conn.send_message @room_id, "There are #{rooms.size} rooms on this HS"
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

      private def garbage_collect
        begin
          rooms = get_rooms Order::JoinedLocalMembers, limit: 0, reverse: true
        rescue ex : Connection::ExecError
          @conn.send_message @room_id, "Error: #{ex.message}"
          return
        end

        idx = -1
        rooms.each_index { |i| rooms[i]["joined_local_members"].as_i == 0 && (idx = i)}
        @conn.send_message @room_id, "Found #{idx + 1} rooms to garbage collect"
      end

      private def get_rooms(order = Order::Name, limit = 10, reverse = false)
        response = @conn.get "/v1/rooms", is_admin: true, order_by: order
        rooms = response["rooms"].as_a

        while (limit == 0 || rooms.size <= limit) && (next_batch = response["next_batch"]?)
          if reverse
            response = @conn.get "/v1/rooms", is_admin: true, order_by: order, from: next_batch, dir: "b"
          else
            response = @conn.get "/v1/rooms", is_admin: true, order_by: order, from: next_batch
          end
          rooms.concat response["rooms"].as_a
        end

        return rooms
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
          @conn.send_message @room_id, "#{room_id} purged"
        end
      end

      private def top_rooms(order : Order) : Nil
        begin
          rooms = get_rooms order
        rescue ex : Connection::ExecError
          @conn.send_message @room_id, "Error: #{ex.message}"
        else
          msg = build_rooms_list rooms[0, 10], order.to_s
          html = build_rooms_list rooms[0, 10], order.to_s, is_html: true
          @conn.send_message @room_id, msg, html
        end
      end
    end
  end
end
