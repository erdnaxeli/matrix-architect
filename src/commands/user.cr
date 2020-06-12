require "option_parser"

require "../connection"
require "./base"

module Matrix::Architect
  module Commands
    class User < Base
      def parse(parser, job)
        parser.banner = "!user COMMAND"
        parser.on("deactivate", "deactivate an account") do
          parser.banner = "!user deactivate USER_ID"
          parser.unknown_args do |before, _|
            if before.size != 1
              job.help
            elsif user_id = before[0]?
              job.exec { deactivate(user_id) }
            else
              job.help
            end
          end
        end
        parser.on("list", "list users") do
          guest = true
          user_id : String? = nil
          parser.banner = "!user list [--no-guests] [--user-id FILTER]"
          parser.on("--no-guests", "don't list guests") { guest = false }
          parser.on("--user-id FILTER", "filter users") { |filter| user_id = filter }
          job.exec { list(guest, user_id) }
        end
        parser.on("reset-password", "reset a user's password and return the new password") do
          logout = true
          parser.banner = "!user reset-password [--no-logout] USER_ID"
          parser.on("--no-logout", "don't log the user out of all their devices") { logout = false }
          parser.unknown_args do |before, _|
            if user_id = before[0]?
              job.exec { reset_password(user_id, logout) }
            else
              job.help
            end
          end
        end
        parser.on("query", "return informations about a specific user account") do
          parser.unknown_args do |before, _|
            if user_id = before[0]?
              job.exec { query(user_id) }
            else
              job.help
            end
          end
        end
      end

      private def build_users_msg(users, html = false, limit = 10)
        String.build do |str|
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

      private def deactivate(user_id)
        @conn.post("/v1/deactivate/#{user_id}", is_admin: true)
      rescue ex : Connection::ExecError
        send_message "Error while deactivating the user: #{ex.message}"
      else
        send_message "user deactivated"
      end

      private def list(guests = true, user_id : String? = nil) : Nil
        params = {guest: guests, user_id: user_id}
        response = @conn.get "/v2/users", **params, is_admin: true
        users = response["users"].as_a

        while next_token = response["next_token"]?
          response = @conn.get "/v2/users", **params, is_admin: true, from: next_token.as_s
          users.concat(response["users"].as_a)
        end
      rescue ex : Connection::ExecError
        send_message "Error while getting users list: #{ex.message}"
      else
        msg = build_users_msg(users)
        html = build_users_msg(users, html: true)
        send_message msg, html
      end

      private def reset_password(user_id, logout) : Nil
        password = Random::Secure.base64(32)[0...-1]
        response = @conn.post(
          "/v1/reset_password/#{user_id}",
          {logout_devices: logout, new_password: password},
          is_admin: true,
        )
      rescue ex : Connection::ExecError
        send_message "Error: #{ex.message}"
      else
        puts response
        send_message "The new password is #{password}"
      end

      private def query(user_id)
        response = @conn.get("/v2/users/#{user_id}", is_admin: true)
      rescue ex : Connection::ExecError
        send_message "Error: #{ex.message}"
      else
        msg = response.to_pretty_json
        send_message "```\n#{msg}\n```", "<pre>#{msg}</pre>"
      end
    end
  end
end
