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
    # A job to be executed.
    class Job
      @block : Proc(Nil)? = nil
      getter help_msg : String? = nil

      def initialize(@parser : OptionParser)
      end

      # Calls the job.
      def call : Nil
        @block.try &.call
      end

      # Registers the block to be executed on job call.
      def exec(&@block)
      end

      # Registers the help to be shown.
      def help
        @help_msg = @parser.to_s if @help_msg.nil?
      end
    end

    def self.run(line, room_id, conn) : Nil
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

      # flag to ignore command
      # The bot may be listening in a room where users talk, we don't want it
      #  to respond help to every message which is not a valid command.
      ignore = true
      legacy = false

      parser = OptionParser.new
      job = Job.new(parser)

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
        User.new(room_id, conn).parse(parser, job)
      end
      parser.on("!version", "get Synapse and Python versions") do
        ignore = false
        Version.new(room_id, conn).parse(parser, job)
      end
      parser.on("-h", "show this help") do
        job.help
        ignore = true
      end
      parser.invalid_option do
        job.help unless ignore || legacy
        ignore = true
      end
      parser.missing_option { job.help }
      parser.unknown_args do |before, after|
        if !ignore && !legacy && (!before.empty? || !after.empty?)
          job.help
          ignore = true
        end
      end

      parser.parse(args2)

      if msg = job.help_msg
        conn.send_message(room_id, msg)
      else
        job.call
      end
    end
  end
end
