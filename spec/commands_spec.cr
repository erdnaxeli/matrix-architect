require "json"

require "./spec_helper"
require "../src/commands"

class FakeConnection
  include Matrix::Architect::Connection

  getter room_id
  getter msg
  getter html_msg
  getter user_id = "dummy"

  def send_message(@room_id : String, @msg : String, @html_msg : String? = nil)
    "dummy"
  end

  def get(path, **options) : JSON::Any
    JSON.parse("{}")
  end

  def post(path, data = nil, **options) : JSON::Any
    JSON.parse("{}")
  end

  def edit_message(room_id : String, event_id : String, message : String, html : String? = nil)
  end
end

describe Matrix::Architect::Commands do
  describe ".run" do
    it "handles help" do
      conn = FakeConnection.new
      Matrix::Architect::Commands.run("!help", "42", conn)

      conn.room_id.should eq "42"
      conn.msg.should eq "Manage your matrix server.
    !bot                             manage the bot itself
    !room                            manage rooms
    !user                            manage users
    !version                         get Synapse and Python versions
    -h                               show this help"
    end
  end
end
