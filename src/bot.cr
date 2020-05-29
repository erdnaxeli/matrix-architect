require "./connection"

module Matrix::Architect
  module Bot
    def self.run(hs_url, access_token)
      conn = Connection.new(hs_url, access_token)
    end
  end
end
