require "./user"
require "./version"

module Matrix::Architect
  module Commands
    def self.run(line, room_id, conn) : Nil
      args = line.split(" ").reject { |v| v == "" }
      command = args.shift

      case command
      when "!help"
        msg = String.build do |str|
          str << "!help\nDisplay this help.\n\n"
          User.usage str
          str << "\n"
          Version.usage str
        end

        conn.send_message room_id, msg
      when "!user"
        User.run args, room_id, conn
      when "!version"
        Version.run args, room_id, conn
      else
      end
    end
  end
end
