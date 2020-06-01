require "./user"

module Matrix::Architect
  module Commands
    def self.run(line, room_id, conn)
      args = line.split(" ").reject { |v| v == "" }
      command = args.shift

      case command
      when "!user"
        User.run args, room_id, conn
      when "!help"
        msg = String.build do |str|
          str << "!help\nDisplay this help.\n\n"
          User.usage str
        end

        conn.send_message room_id, msg
      else
      end
    end
  end
end
