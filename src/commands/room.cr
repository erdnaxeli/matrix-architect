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
!room list [--room-id FILTER]
  List rooms.
    --alias FILTER    filter on rooms's id
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
          details args.pop?
        when "garbage-collect"
          garbage_collect
        when "list"
          list args
        when "top-complexity"
          top_rooms Order::StateEvents
        when "top-local-members"
          top_rooms Order::JoinedLocalMembers
        when "top-members"
          top_rooms Order::JoinedMembers
        when "purge"
          purge args.pop?
        else
          @conn.send_message @room_id, "Unknown command"
        end
      end

      private def build_rooms_list(rooms, key : String? = nil, limit = 0, is_html : Bool = false)
        String.build do |str|
          if is_html
            str << "<ul>"
          end

          rooms[0, (limit > 0) ? limit : rooms.size].each do |room|
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

            str << room["room_id"].as_s
            if key
              str << " " << room[key]
            end

            str << "\n"

            if is_html
              str << "</li>"
            end
          end

          if is_html
            str << "</ul>"
          end

          if limit > 0 && rooms.size > limit
            str << "\nToo many rooms (" << rooms.size << "), "
            str << "showing only the " << limit << " first ones."
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

      private def details(room_id : String?) : Nil
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

      private def garbage_collect : Nil
        begin
          rooms = get_rooms(Order::JoinedLocalMembers, limit: 0, reverse: true)
        rescue ex : Connection::ExecError
          @conn.send_message(@room_id, "Error: #{ex.message}")
          return
        end

        idx = -1
        # TODO: is there a way to not go through all the rooms?
        rooms.each_index { |i| rooms[i]["joined_local_members"].as_i == 0 && (idx = i) }

        if idx == -1
          @conn.send_message(@room_id, "No rooms found for garbage collection")
          return
        end

        total = idx + 1
        @conn.send_message(@room_id, "Found #{total} rooms to garbage collect")
        event_id = @conn.send_message(@room_id, "starting")

        begin
          count = 0
          ten_percent_bucket = (total) / 10
          t_message = t_start = Time.utc


          rooms[0, total].each do |room|
            count += 1
            purge(room["room_id"].as_s, silent: true)

            # update the message every 20s
            if (Time.utc - t_message).total_seconds >= 20
              t_message = Time.utc
              elapsed_time = t_message - t_start
              f_elapsed = time_span_to_s(elapsed_time)
              percents = 100 * count / total
              @conn.edit_message(
                @room_id,
                event_id,
                "#{count}/#{total} #{percents}% #{f_elapsed}"
              )
            end
          end

          elapsed_time = Time.utc - t_start
          f_elapsed = time_span_to_s(elapsed_time)
          @conn.edit_message(@room_id, event_id, "garbage-collection done in #{f_elapsed}")
        rescue ex : Connection::ExecError
          @conn.send_message(@room_id, "Error: #{ex.message}")
        end
      end

      private def list(args) : Nil
        fail = false
        room_alias = nil
        OptionParser.parse(args) do |parser|
          parser.on("--alias FILTER", "filter on rooms' id") { |filter| room_alias = filter }
          parser.invalid_option { fail = true }
          parser.missing_option { fail = true }
        end

        if fail
          @conn.send_message(@room_id, "Invalid command")
          return
        end

        begin
          rooms = get_rooms(Order::Name, limit: 0)
        rescue ex : Connection::ExecError
          @conn.send_message(@room_id, "Error: #{ex.message}")
          return
        end

        if filter = room_alias
          rooms.select! { |room| room["canonical_alias"].as_s?.try &.includes?(filter) }
        end

        if rooms.size == 0
          @conn.send_message(@room_id, "No rooms found")
        else
          msg = build_rooms_list(rooms, limit: 10)
          html = build_rooms_list(rooms, limit: 10, is_html: true)
          @conn.send_message(@room_id, msg, html)
        end
      end

      private def time_span_to_s(span : Time::Span) : String
        if span.total_seconds <= 60
          return "#{span.seconds}s"
        else
          return "#{span.total_minutes.to_i}m#{span.seconds}s"
        end
      end

      private def get_rooms(order = Order::Name, limit = 10, reverse = false)
        dir = (reverse) ? "b" : "f"
        response = @conn.get "/v1/rooms", is_admin: true, order_by: order, dir: dir
        rooms = response["rooms"].as_a

        while (limit == 0 || rooms.size <= limit) && (next_batch = response["next_batch"]?)
          response = @conn.get "/v1/rooms", is_admin: true, order_by: order, from: next_batch, dir: dir
          rooms.concat response["rooms"].as_a
        end

        return rooms
      end

      private def purge(room_id : String?, silent = false) : Nil
        if room_id.nil?
          @conn.send_message @room_id, "Usage: !room purge ROOM_ID"
        end

        if !silent
          @conn.send_message @room_id, "Purge starting, depending on the size of the room it may take a while"
        end

        begin
          @conn.post "/v1/purge_room", is_admin: true, data: {room_id: room_id}
        rescue ex : Connection::ExecError
          @conn.send_message @room_id, "Error: #{ex.message}"
        else
          if !silent
            @conn.send_message @room_id, "#{room_id} purged"
          end
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
