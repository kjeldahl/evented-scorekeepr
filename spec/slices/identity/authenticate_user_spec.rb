require "rails_helper"

RSpec.describe Identity::AuthenticateUser do
  describe ".call", :event_store do
    let!(:user_id) do
      Identity::RegisterUser.call(name: "Alice", email: "alice@example.com", password: "secret123").value
    end

    it "succeeds with the user id for correct credentials" do
      result = described_class.call(email: "alice@example.com", password: "secret123")
      expect(result).to eq(Result.success(user_id))
    end

    it "normalises the email before lookup" do
      result = described_class.call(email: "  ALICE@Example.com ", password: "secret123")
      expect(result).to eq(Result.success(user_id))
    end

    it "fails with invalid credentials for a wrong password" do
      result = described_class.call(email: "alice@example.com", password: "wrong-secret")
      expect(result).to eq(Result.failure("invalid credentials"))
    end

    it "fails with invalid credentials for an unknown email" do
      result = described_class.call(email: "nobody@example.com", password: "secret123")
      expect(result).to eq(Result.failure("invalid credentials"))
    end

    it "fails with invalid credentials for a missing email instead of raising" do
      result = described_class.call(email: nil, password: "secret123")
      expect(result).to eq(Result.failure("invalid credentials"))
    end

    it "fails with invalid credentials for a missing password instead of raising" do
      result = described_class.call(email: "alice@example.com", password: nil)
      expect(result).to eq(Result.failure("invalid credentials"))
    end
  end
end
