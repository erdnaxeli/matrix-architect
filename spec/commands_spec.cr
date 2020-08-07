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

  describe ".parse" do
    it "parses args" do
      args = Matrix::Architect::Commands.parse("!this is a  command --with some --flags")
      args.should eq ["!this", "is", "a", "command", "--with", "some", "--flags"]
    end

    it "handles double quotes" do
      args = Matrix::Architect::Commands.parse(%(!this is "a  command" --))
      args.should eq ["!this", "is", "a  command", "--"]
    end

    it "handles simple quotes" do
      args = Matrix::Architect::Commands.parse(%(!this is 'a  command'))
      args.should eq ["!this", "is", "a  command"]
    end

    it "handles very weird cases" do
      args = Matrix::Architect::Commands.parse(%(!this 'is a "'very wei"rd co"m"mand please" don't do t'h'a't p"leas"e))
      args.should eq ["!this", %(is a "very), "weird command please", "dont do that", "please"]
    end

    it "handles error" do
      args = Matrix::Architect::Commands.parse(%(!this is an "error))
      args.should eq ["-h"]
    end
  end
end
