require "../connection"
require "./base"

module Matrix::Architect
  module Commands
    class Version < Base
      def parse(parser, job) : Nil
        parser.banner = "!version"
        job.exec do
          begin
            response = @conn.get "/v1/server_version", is_admin: true
          rescue ex : Connection::ExecError
            send_message "Error: #{ex.message}"
          else
            msg = response.to_pretty_json
            send_message "```\n#{msg}\n```", "<pre>#{msg}</pre>"
          end
        end
      end
    end
  end
end
