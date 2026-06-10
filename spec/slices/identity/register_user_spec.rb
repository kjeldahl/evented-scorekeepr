require "rails_helper"

RSpec.describe Identity::RegisterUser do
  def call(name: "Alice", email: "alice@example.com", password: "secret123")
    described_class.call(name:, email:, password:)
  end

  def stored_events
    EventStore.read(DcbEventStore::Query.all)
  end

  describe "validation" do
    it "rejects a blank name" do
      expect(call(name: "  ")).to eq(Result.failure("name is required"))
    end

    it "rejects a nil name" do
      expect(call(name: nil)).to eq(Result.failure("name is required"))
    end

    it "rejects a blank email" do
      expect(call(email: " ")).to eq(Result.failure("email is required"))
    end

    it "rejects a nil email" do
      expect(call(email: nil)).to eq(Result.failure("email is required"))
    end

    it "rejects a blank password" do
      expect(call(password: "")).to eq(Result.failure("password is required"))
    end

    it "rejects a nil password" do
      expect(call(password: nil)).to eq(Result.failure("password is required"))
    end

    it "appends nothing when validation fails", :event_store do
      call(name: "")
      expect(stored_events).to be_empty
    end
  end

  describe "successful registration", :event_store do
    it "returns success with the new user id" do
      result = call
      expect(result).to be_success
      expect(result.value).to be_a(String)
    end

    it "appends a UserRegistered event with the normalised email and stripped name" do
      result = call(name: " Alice ", email: " ALICE@Example.com ")
      event = stored_events.sole
      expect(event.type).to eq("UserRegistered")
      expect(event.data[:user_id]).to eq(result.value)
      expect(event.data[:name]).to eq("Alice")
      expect(event.data[:email]).to eq("alice@example.com")
      expect(event.tags).to contain_exactly("user:#{result.value}", "user_email:alice@example.com")
    end

    it "stores a BCrypt digest of the password, not the password itself" do
      call(password: "secret123")
      digest = stored_events.sole.data[:password_digest]
      expect(digest).not_to include("secret123")
      expect(BCrypt::Password.new(digest)).to eq("secret123")
    end

    it "generates a distinct user id per registration" do
      first = call(email: "a@example.com")
      second = call(email: "b@example.com")
      expect(first.value).not_to eq(second.value)
    end
  end

  describe "email uniqueness", :event_store do
    before { call(email: "bob@x.com") }

    it "rejects a duplicate email" do
      expect(call(name: "Robert", email: "bob@x.com")).to eq(Result.failure("email is already registered"))
    end

    it "rejects a duplicate email regardless of case and whitespace" do
      expect(call(name: "Robert", email: " BOB@x.com ")).to eq(Result.failure("email is already registered"))
    end

    it "appends nothing for a duplicate" do
      expect { call(email: "bob@x.com") }.not_to change { stored_events.size }
    end
  end

  describe "concurrency conflict", :event_store do
    it "maps ConditionNotMet to the duplicate-email failure" do
      allow(EventStore).to receive(:append).and_raise(DcbEventStore::ConditionNotMet)
      expect(call).to eq(Result.failure("email is already registered"))
    end
  end
end
