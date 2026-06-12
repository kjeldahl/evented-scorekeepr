require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:session_key) { Rails.application.config.session_options[:key] }

  # The test cookie jar treats a Hash as cookie options, so the session
  # payload (a hash with string keys, like the real cookie store round-trips)
  # is wrapped in value:.
  it "identifies the connection by the user id in the session cookie" do
    cookies.encrypted[session_key] = { value: { "user_id" => "user-1" } }
    connect "/cable"
    expect(connection.current_user_id).to eq("user-1")
  end

  it "rejects a connection without a session cookie" do
    expect { connect "/cable" }.to have_rejected_connection
  end

  it "rejects a connection whose session has no user id" do
    cookies.encrypted[session_key] = { value: { "something_else" => "x" } }
    expect { connect "/cable" }.to have_rejected_connection
  end
end
