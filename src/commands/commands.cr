require "./room"
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
          str << "!help\n  Display this help.\n"
          Room.usage str
          User.usage str
          Version.usage str
        end
        conn.send_message room_id, msg
      when "!room"
        Room.run args, room_id, conn
      when "!user"
        User.run args, room_id, conn
      when "!version"
        Version.run args, room_id, conn
      else
      end
    end
  end
end
