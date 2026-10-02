require "rails_helper"

RSpec.describe Identity::HandOffSuperAdmin, :event_store do
  def register(user_id)
    EventStore.append(
      Identity::Events.user_registered(
        user_id:, name: user_id, email: "#{user_id}@example.com", password_digest: "digest"
      )
    )
  end

  def holder
    EventStore.decide(s: Identity::CurrentSuperAdmin.projection).states.fetch(:s)
  end

  def stored
    EventStore.read(DcbEventStore::Query.all).map(&:type)
  end

  before do
    %w[root alice bob].each { |id| register(id) }
    Identity::GrantSuperAdmin.call(user_id: "root")
  end

  it "makes the recipient the only super admin" do
    result = described_class.call(actor_user_id: "root", email: "alice@example.com")
    expect(result).to eq(Result.success("alice"))
    expect(holder).to eq("alice")
  end

  it "appends the revocation and the grant" do
    described_class.call(actor_user_id: "root", email: "alice@example.com")
    expect(stored.last(2)).to eq(%w[SuperAdminRevoked SuperAdminGranted])
  end

  it "matches the email trimmed and case-insensitively" do
    described_class.call(actor_user_id: "root", email: "  ALICE@Example.com ")
    expect(holder).to eq("alice")
  end

  it "can be handed on again" do
    described_class.call(actor_user_id: "root", email: "alice@example.com")
    described_class.call(actor_user_id: "alice", email: "bob@example.com")
    expect(holder).to eq("bob")
  end

  it "rejects a non-super-admin and appends nothing" do
    expect { @result = described_class.call(actor_user_id: "alice", email: "bob@example.com") }
      .not_to change { stored.size }
    expect(@result).to eq(Result.failure("only the super admin can hand off the super admin status"))
  end

  it "rejects the previous super admin" do
    described_class.call(actor_user_id: "root", email: "alice@example.com")
    result = described_class.call(actor_user_id: "root", email: "bob@example.com")
    expect(result).to eq(Result.failure("only the super admin can hand off the super admin status"))
    expect(holder).to eq("alice")
  end

  it "rejects an unknown email" do
    expect { @result = described_class.call(actor_user_id: "root", email: "nobody@example.com") }
      .not_to change { stored.size }
    expect(@result).to eq(Result.failure("there is no user with that email"))
  end

  it "rejects a blank or nil email" do
    expect(described_class.call(actor_user_id: "root", email: "")).to eq(Result.failure("there is no user with that email"))
    expect(described_class.call(actor_user_id: "root", email: nil)).to eq(Result.failure("there is no user with that email"))
  end

  it "checks the actor before the recipient" do
    result = described_class.call(actor_user_id: "alice", email: "nobody@example.com")
    expect(result.error).to eq("only the super admin can hand off the super admin status")
  end

  it "is a no-op success when handing to oneself" do
    expect { @result = described_class.call(actor_user_id: "root", email: "root@example.com") }
      .not_to change { stored.size }
    expect(@result).to eq(Result.success("root"))
  end

  it "re-decides after a lost race" do
    raced = false
    allow(EventStore).to receive(:append).and_wrap_original do |original, *args|
      unless raced
        raced = true
        original.call([ Identity::Events.super_admin_revoked(user_id: "root"), Identity::Events.super_admin_granted(user_id: "bob") ])
      end
      original.call(*args)
    end
    result = described_class.call(actor_user_id: "root", email: "alice@example.com")
    expect(result.error).to eq("only the super admin can hand off the super admin status")
    expect(holder).to eq("bob")
  end
end
