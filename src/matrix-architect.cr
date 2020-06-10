require "log"
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

  def self.get_config
    begin
      config = File.open("config.yml") do |file|
        Config.from_yaml(file)
      end
    rescue File::NotFoundError
      puts "Configuration file 'config.yml' not found"
      return
    rescue ex : YAML::ParseException
      puts "Error while reading config file: #{ex.message}"
    end

    return config
  end

  def self.run
    config = get_config
    if !config.nil?
      ::Log.setup(config.log_level)
      Bot.new(config).run
    end
  end
end

Matrix::Architect.run
