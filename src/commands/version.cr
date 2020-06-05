require "../connection"

module Matrix::Architect
  module Commands
    module Version
      def self.run(args, room_id, conn)
        begin
          response = conn.get "/v1/server_version", is_admin: true
        rescue ex : Connection::ExecError
          conn.send_message(room_id, "Error: #{ex.message}")
        else
          msg = response.to_pretty_json
          conn.send_message(room_id, "```\n#{msg}\n```", "<pre>#{msg}</pre>")
        end
      end

      def self.usage(str)
        str << "\
!version
  Get Synapse and Python versions.
"
      end
    end
  end
end
