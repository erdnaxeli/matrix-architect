require "yaml"

require "./bot"

module Matrix::Architect
  VERSION = "0.1.0"

  def self.get_config
    begin
      config = File.open("config.yml") do |file|
        YAML.parse(file)
      end.as_h?
    rescue File::NotFoundError
      puts "Configuration file 'config.yml' not found"
      return
    end

    if config.nil?
      puts "Invalid configuration"
      return
    end

    begin
      access_token = config["access_token"].as_s?
    rescue KeyError
      puts "Invalid configuration: missing access_token"
      return
    end

    begin
      hs_url = config["homeserver"].as_s?
    rescue KeyError
      puts "Invalid configuration: missing homeserver"
      return
    end
    if access_token.nil? || hs_url.nil?
      puts "Invalid configuration"
      return
    end

    return access_token, hs_url
  end

  def self.run
    config = self.get_config
    if !config.nil?
      access_token, hs_url = config
      bot = Bot.run(hs_url, access_token)
    end
  end
end

Matrix::Architect.run
