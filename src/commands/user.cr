require "option_parser"

require "../connection"

module Matrix::Architect
  module Commands
    class User
      def initialize(@room_id : String, @conn : Connection)
      end

      def self.run(args, room_id, conn)
        User.new(room_id, conn).run(args)
      end

      def run(args)
        command = args.shift?
        begin
          case command
          when "list"
            list args
          when "reset-password"
            reset_password args
          else
            @conn.send_message @room_id, "Unknown command"
          end
        rescue OptionParser::InvalidOption | OptionParser::MissingOption
          usage = case command
                  when "list"
                    list_usage
                  when "reset-password"
                    reset_password_usage
                  else
                    "unknown command"
                  end

          @conn.send_message @room_id, "Invalid command, usage: user #{usage}"
        end
      end

      def self.usage(str)
        str << "\
user list [--no-guests] [--user-id FILTER]
List users.
  --no-gests          do not list guests users
  --user-id FILTER    filter on users' id

user reset-password [--no-logout] USER_ID
Reset a user's password and return the new password
  --no-logout         do not log the user out of all their devices
        "
      end

      private def build_users_msg(users, html = false, limit = 10)
        return String.build do |str|
          str << users.size << " users found:\n"

          if html
            str << "<ul>"
          end

          users[0, limit].each do |user|
            if html
              str << "<li>"
            else
              str << "* "
            end

            str << user["name"].as_s
            str << %( ") << user["displayname"] << %(")

            if user["is_guest"].as_i == 1
              str << " guest"
            end

            if user["admin"].as_i == 1
              str << " admin"
            end

            if user["deactivated"].as_i == 1
              str << " deactivated"
            end

            if html
              str << "</li>"
            else
              str << "\n"
            end
          end

          if html
            str << "</ul>"
          end

          if users.size > limit
            str << "\nToo many users, "
            str << "showing only the " << limit << " first ones."
          end
        end
      end

      private def list(args) : Nil
        guests = true
        user_id = nil
        OptionParser.parse(args) do |parser|
          parser.banner = "List users"
          parser.on("--no-guests", "do not list guests") { guests = false }
          parser.on("--user-id FILTER", "filter users containing this value") { |filter| user_id = filter }
        end

        params = {guest: guests, user_id: user_id}
        response = @conn.get "/v2/users", **params, is_admin: true
        users = response["users"].as_a

        while next_token = response["next_token"]?
          response = @conn.get "/v2/users", **params, is_admin: true, from: next_token.as_s
          users.concat(response["users"].as_a)
        end

        msg = build_users_msg users
        html = build_users_msg users, html: true
        @conn.send_message @room_id, msg, html
      end

      private def list_usage
        "list [--no-guests] [--user_id FILTER]"
      end

      private def reset_password(args) : Nil
        logout = true
        user_id = args.pop
        OptionParser.parse(args) do |parser|
          parser.banner = "Reset a user password"
          parser.on("--no-logout", "do not logout the user") { logout = false }
        end

        password = Random::Secure.base64(32)[0...-1]
        begin
          response = @conn.post(
            "/v1/reset_password/#{user_id}",
            {logout_devices: logout, new_password: password},
            is_admin: true,
          )
        rescue ex : Connection::ExecError
          @conn.send_message @room_id, "Error: #{ex.message}"
        else
          puts response
          @conn.send_message @room_id, "The new password is #{password}"
        end
      end

      private def reset_password_usage
        "reset-password [--no-logout]"
      end
    end
  end
end
