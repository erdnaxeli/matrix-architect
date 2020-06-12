require "./commands/*"

require "option_parser"

# OptionParser fixed so sub commands with hyphen work.
# See https://github.com/crystal-lang/crystal/pull/9465
class OptionParser
  private def parse_flag_definition(flag : String)
    case flag
    when /^--(\S+)\s+\[\S+\]$/
      {"--#{$1}", FlagValue::Optional}
    when /^--(\S+)(\s+|\=)(\S+)?$/
      {"--#{$1}", FlagValue::Required}
    when /^--\S+$/
      # This can't be merged with `else` otherwise /-(.)/ matches
      {flag, FlagValue::None}
    when /^-(.)\s*\[\S+\]$/
      {flag[0..1], FlagValue::Optional}
    when /^-(.)\s+\S+$/, /^-(.)\s+$/, /^-(.)\S+$/
      {flag[0..1], FlagValue::Required}
    else
      # This happens for -f without argument
      {flag, FlagValue::None}
    end
  end
end

module Matrix::Architect
  module Commands
    class Job
      block : Proc(Nil)? = nil

      def exec(&@block)
      end

      def call : Nil
        @block.try &.call
      end
    end

    def self.run(line, room_id, conn) : Nil
      # flag to ignore command
      # The bot may be listening in a room where users talk, we don't want it
      #  to respond help to every message which is not a valid command.
      ignore = true
      legacy = false
      job = Job.new

      args = line.split(" ").reject { |v| v == "" }
      args.shift

      args2 = line.split(" ").reject { |v| v == "" }
      if command = args2[0]?
        if command[0] != '!'
          return
        elsif command == "!help"
          # When a subcommand is passed, others a removed from the parser, so
          # an "!help" subcommand could not see others.
          # We trick the parser by changer "!help" to "-h".
          args2 = ["-h"]
        end
      else
        return
      end

      OptionParser.parse(args2) do |parser|
        parser.banner = "Manage your matrix server."
        parser.on("!bot", "manage the bot itself") do
          ignore = false
          Bot.new(room_id, conn).parse(parser, job)
        end
        parser.on("!room", "manage rooms") do
          ignore = false
          legacy = true
          job.exec { Room.run(args, room_id, conn) }
        end
        parser.on("!user", "manage users") do
          ignore = false
          legacy = true
          job.exec { User.run(args, room_id, conn) }
        end
        parser.on("!version", "get synapse version") do
          ignore = false
          legacy = true
          job.exec { Version.run(args, room_id, conn) }
        end
        parser.on("-h", "show this help") do
          conn.send_message(room_id, parser.to_s)
          ignore = true
        end
        parser.invalid_option do
          conn.send_message(room_id, parser.to_s) unless ignore || legacy
          ignore = true
        end
        parser.missing_option { conn.send_message(room_id, parser.to_s) }
        parser.unknown_args do |before, after|
          if !ignore && !legacy && (!before.empty? || !after.empty?)
            conn.send_message(room_id, parser.to_s)
            ignore = true
          end
        end
      end

      if !ignore
        job.call
      end
    end
  end
end
