require "http/client"
require "http/headers"
require "json"
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

  def self.run : Nil
    config_file = "config.yml"
    gen = false

    OptionParser.parse do |parser|
      parser.on("gen-config", "generate the configuration file") { gen = true }
      parser.on("--config CONFIG_FILE", "specify a config file") { |c| config_file = c }
      parser.on("-h", "--help", "show this help") do
        puts parser
        exit
      end
    end

    if gen
      gen_config config_file
    else
      config = get_config(config_file)
      if !config.nil?
        ::Log.setup(config.log_level)
        Bot.new(config).run
      end
    end
  end

  def self.gen_config(filename) : Nil
    if File.exists?(filename)
      puts "File #{filename} already exists, do you want to overwrite it? (y/N) "
      overwrite = STDIN.gets.try { |r| r == "y" } || false
      if !overwrite
        return
      end
    end

    hs_url = read_var("Enter the homeserver URL: ")
    if !hs_url.starts_with?(/https?:\/\//)
      hs_url = "https://#{hs_url}"
    end

    user_id = read_var("Enter the bot's user id: ")
    user_password = read_var("Enter the bot's password: ", secret: true)
    users = read_list("Enter the allowed bot administrators, end with an empty line: ")

    response = HTTP::Client.post(
      "#{hs_url}/_matrix/client/r0/login",
      headers: HTTP::Headers{"Content-Type" => "application/json"},
      body: {
        type:       "m.login.password",
        identifier: {
          type: "m.id.user",
          user: user_id,
        },
        password: user_password,
      }.to_json
    )
    if response.status_code != 200
      puts "Got an response from the homserver with status code #{response.status_code}: #{response.body}"
    end

    data = Hash(String, String).from_json(response.body)
    if !data.has_key?("access_token")
      puts "Unkwon response from homeserver: #{data}"
      return
    end

    File.open(filename, mode: "w") do |file|
      file << "---
homeserver: #{hs_url}
access_token: #{data["access_token"]}
log_level: info
users: "
      if users.empty?
        file << "[]\n"
      else
        file << "\n"
        users.each { |user| file << "  - \"" << user << "\"\n" }
      end
    end

    puts "Configuration file written!"
  end

  def self.read_var(prompt, secret = false, allow_empty = false) : String
    result = nil
    loop do
      print prompt
      if secret
        result = STDIN.noecho &.gets
        puts
      else
        result = STDIN.gets
      end

      break if result || allow_empty
    end

    if result.nil?
      ""
    else
      result
    end
  end

  def self.read_list(prompt) : Array(String)
    result = Array(String).new
    puts prompt
    loop do
      var = read_var("", allow_empty: true)
      break if var == ""
      result << var
    end

    result
  end
end
