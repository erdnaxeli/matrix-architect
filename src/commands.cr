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

      def empty? : Bool
        @block.nil?
      end

      # Registers the block to be executed on job call.
      def exec(&@block)
      end

      # Registers the help to be shown.
      def help
        @help_msg = @parser.to_s if @help_msg.nil?
      end
    end

    def self.run(line : String, room_id : String, conn : Connection) : Nil
      args = parse(line)
      if !args.size || args[0][0] != '!'
        return
      end

      parser = OptionParser.new
      job = Job.new(parser)

      parser.banner = "Manage your matrix server."
      parser.on("!bot", "manage the bot itself") do
        Bot.new(room_id, conn).parse(parser, job)
      end
      parser.on("!room", "manage rooms") do
        Room.new(room_id, conn).parse(parser, job)
      end
      parser.on("!user", "manage users") do
        User.new(room_id, conn).parse(parser, job)
      end
      parser.on("!version", "get Synapse and Python versions") do
        Version.new(room_id, conn).parse(parser, job)
      end
      parser.on("-h", "show this help") do
        job.help
      end
      parser.invalid_option do
        job.help
      end
      parser.missing_option { job.help }
      parser.unknown_args do |_, _|
        # `unknown_args` is always called last, so if no job have been registered
        # when we got here we just show the help.
        # This acts like a `missing_subcommand` method.
        if job.empty?
          job.help
        end
      end

      parser.parse(args)

      if msg = job.help_msg
        conn.send_message(room_id, msg)
      else
        job.call
      end
    end

    def self.parse(line)
      delimiter = nil
      args = [] of String
      acc = String::Builder.new

      line.each_char do |c|
        if delimiter.nil?
          if c == ' '
            if acc.empty?
              next
            else
              args << acc.to_s
              acc = String::Builder.new
            end
          elsif c == '"' || c == '\''
            delimiter = c
          else
            acc << c
          end
        else
          if c == delimiter
            delimiter = nil
          else
            acc << c
          end
        end
      end

      if !delimiter.nil?
        # there is a odd number of delimiter
        ["-h"]
      else
        args << acc.to_s
        args
      end
    end
  end
end
