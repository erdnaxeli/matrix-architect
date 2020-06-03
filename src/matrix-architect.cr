require "yaml"

require "./bot"

module Matrix::Architect
  VERSION = "0.1.0"

  struct Config
    YAML.mapping(
      access_token: String,
      hs_url: {
        key: "homeserver",
        type: String,
      },
      users_id: {
        key: "users",
        type: Array(String),
      }
    )
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
    config = self.get_config
    if !config.nil?
      Bot.new(config).run
    end
  end
end

Matrix::Architect.run
