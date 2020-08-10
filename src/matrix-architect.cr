require "log"
require "option_parser"
require "yaml"

require "./bot"

module Matrix::Architect
  VERSION = "0.1.0"

  Log = ::Log.for(self)

  struct Config
    include YAML::Serializable
    include YAML::Serializable::Strict

    property access_token : String
    property log_level = ::Log::Severity::Info

    @[YAML::Field(key: "homeserver")]
    property hs_url : String

    @[YAML::Field(key: "users")]
    property users_id : Array(String)
  end

  def self.get_config(config_file)
    File.open(config_file) do |file|
      return Config.from_yaml(file)
    end
  rescue File::NotFoundError
    puts "Configuration file '#{config_file}' not found"
  rescue ex : YAML::ParseException
    puts "Error while reading config file: #{ex.message}"
  end

  def self.run
    config_file = "config.yml"
    OptionParser.parse do |parser|
      parser.on("--config CONFIG_FILE", "specify a config file") { |c| config_file = c }
      parser.on("-h", "--help", "show this help") do
        puts parser
        exit
      end
    end

    config = get_config(config_file)
    if !config.nil?
      ::Log.setup(config.log_level)
      Bot.new(config).run
    end
  end
end
