require "option_parser"

require "../connection"
require "./base"

module Matrix::Architect
  module Commands
    class Room < Base
      enum Order
        JoinedLocalMembers
        JoinedMembers
        Name
        StateEvents

        def to_s
          super.underscore
        end
      end

      def parse(parser, job) : Nil
        parser.banner = "!room COMMAND"
        parser.on("count", "return the total count of rooms") do
          parser.banner = "!room count"
          job.exec { count }
        end
        parser.on("delete", "make all users leave a room and purge it") do
          block = false
          shutdown = false
          message = nil

          parser.banner = "!room delete [--block] [--purge] [--msg MSG] ROOM_ID"
          parser.on("--block", "prevent joining this room again") do
            block = true
          end
          parser.on("--msg MSG", "make all the users join a new room where a message will be shown") do |msg|
            message = msg
          end
          parser.unknown_args do |before, _|
            if before.size != 1
              job.help
            else
              job.exec { delete(before[0], block, message) }
            end
          end
        end
        parser.on("details", "get all details about a room") do
          parser.banner = "!room details ROOM_ID"
          parser.unknown_args do |before, _|
            if before.size != 1
              job.help
            else
              job.exec { details(before[0]) }
            end
          end
        end
        parser.on("garbage-collect", "purge all rooms without any local users joined") do
          parser.banner = "!room garbage-collect"
          job.exec { garbage_collect }
        end
        parser.on("list", "list rooms") do
          room_alias = nil
          parser.banner = "!room list [--alias FILTER]"
          parser.on("--alias FILTER", "filter on room's id") { |filter| room_alias = filter }

          job.exec { list room_alias }
        end
        parser.on("top-complexity", "get top 10 rooms by complexity, aka state events number") do
          parser.banner = "!room top-complexity"
          job.exec { top_rooms(Order::StateEvents) }
        end
        parser.on("top-local-members", "get top 10 rooms by local members count") do
          parser.banner = "!room top-local-member"
          job.exec { top_rooms(Order::JoinedLocalMembers) }
        end
        parser.on("top-members", "get top 10 rooms by members count") do
          parser.banner = "!room top-members"
          job.exec { top_rooms(Order::JoinedMembers) }
        end
        parser.on("purge", "remove all traces of a room from your database") do
          parser.banner = "!room purge ROOM_ID"
          parser.unknown_args do |before, _|
            if before.size != 1
              job.help
            else
              job.exec { purge(before[0]) }
            end
          end
        end
        parser.on("shutdown", "make all local users leave a room and remove its local aliases") do
          parser.unknown_args do |before, _|
            if before.size != 1
              job.help
            else
              job.exec { shutdown(before[0]) }
            end
          end
        end
      end

      private def build_rooms_list(rooms, key : String? = nil, limit = 0, is_html : Bool = false)
        String.build do |str|
          if is_html
            str << "<ul>"
          end

          rooms[0, (limit > 0) ? limit : rooms.size].each do |room|
            build_room_list(room, str, key, is_html)
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

      private def build_room_list(room, str, key : String? = nil, is_html : Bool = false)
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

      private def count
        rooms = get_rooms limit: 0
      rescue ex : Connection::ExecError
        @conn.send_message(@room_id, "Error: #{ex.message}")
      else
        @conn.send_message(@room_id, "There are #{rooms.size} rooms on this HS")
      end

      private def delete(room_id : String, block = false, message : String? = nil)
        if message.nil?
          data = {block: block}
        else
          data = {
            block:            block,
            message:          message,
            new_room_user_id: @conn.user_id,
          }
        end

        begin
          response = @conn.post("/v1/rooms/#{room_id}/delete", is_admin: true, data: data)
        rescue ex : Connection::ExecError
          @conn.send_message(@room_id, "Error: #{ex.message}")
        else
          msg = response.to_pretty_json
          @conn.send_message(@room_id, "```\n#{msg}\n```", "<pre>#{msg}</pre>")
        end
      end

      private def details(room_id : String?) : Nil
        if room_id.nil?
          @conn.send_message(@room_id, "Usage: !room details ROOM_ID")
          return
        end

        begin
          response = @conn.get "/v1/rooms/#{room_id}", is_admin: true
        rescue ex : Connection::ExecError
          @conn.send_message(@room_id, "Error: #{ex.message}")
        else
          msg = response.to_pretty_json
          @conn.send_message(@room_id, "```\n#{msg}\n```", "<pre>#{msg}</pre>")
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
          t_message = t_start = Time.utc

          rooms[0, total].each do |room|
            count += 1
            do_purge(room["room_id"].as_s)

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

      private def list(room_alias : String? = nil) : Nil
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
          "#{span.seconds}s"
        else
          "#{span.total_minutes.to_i}m#{span.seconds}s"
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

        rooms
      end

      private def purge(room_id : String) : Nil
        msg = "Purge starting, depending on the size of the room it may take a while"
        event_id = @conn.send_message(@room_id, msg)

        run_with_progress(2.seconds) do |runner|
          runner.command do
            if id = room_id
              do_purge(id)
            end
          end
          runner.on_progress do |time|
            @conn.edit_message(@room_id, event_id, "#{msg}: #{time.total_seconds.round}s")
          end
          runner.on_success do |time|
            @conn.edit_message(@room_id, event_id, "#{room_id} purged in #{time.total_seconds.round}s")
          end
        end
      end

      private def do_purge(room_id : String) : Nil
        @conn.post("/v1/purge_room", is_admin: true, data: {room_id: room_id})
      end

      private def shutdown(room_id : String) : Nil
        event_id = @conn.send_message(@room_id, "Shuting down room #{room_id}")
        run_with_progress(20.seconds) do |runner|
          runner.command do
            @conn.post("/v1/shutdown_room/#{room_id}", is_admin: true, data: {new_room_user_id: @conn.user_id})
          end
          runner.on_progress do |time|
            @conn.edit_message(@room_id, event_id, "Shuting down room #{room_id}: #{time.total_seconds.round}s")
          end
          runner.on_success do |time|
            @conn.edit_message(@room_id, event_id, "#{room_id} shutted down in #{time.total_seconds.round}s")
          end
        end
      end

      private def top_rooms(order : Order) : Nil
        rooms = get_rooms(order)
      rescue ex : Connection::ExecError
        @conn.send_message(@room_id, "Error: #{ex.message}")
      else
        msg = build_rooms_list(rooms[0, 10], order.to_s)
        html = build_rooms_list(rooms[0, 10], order.to_s, is_html: true)
        @conn.send_message(@room_id, msg, html)
      end
    end
  end
end
