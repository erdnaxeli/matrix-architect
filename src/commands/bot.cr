require "option_parser"

require "./base"

module Matrix::Architect
  module Commands
    class Bot < Base
      @option = false

      def parse(parser, job) : Nil
        parser.banner = "!bot COMMAND"
        parser.on("leave-rooms", "leave all rooms the bot is in, except the current one") do
          parser.banner = "!bot leave-rooms"
          job.exec { leave_rooms }
        end
      end

      def leave_rooms : Nil
        send_message "leaving"
      end
    end
  end
end
