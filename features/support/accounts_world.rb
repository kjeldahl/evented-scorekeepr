# frozen_string_literal: true

# Account-related world helpers for all slices' step definitions.
#
# Scenarios refer to accounts by name ("Office"); the per-scenario
# `account_ids` registry maps those names to account ids so later steps can
# build paths and query read models.
#
# Public helper API (reuse these in other slices' steps):
#   account_ids                        # account name => account_id
#   remember_account(name, account_id)
#   account_id_for(account_name)       # registered id (raises when unknown)
#   create_account(owner_name, account_name)   # via the domain command + remember
#   ensure_member(user_name, account_name)     # owner invites + user accepts (domain commands), idempotent
#   member_of?(user_name, account_name)
#   invite(inviter_name, email, account_name)  # through the real invite-player UI
#   latest_invitation_id(account_name)         # newest invitation for the account (from the event store)
module AccountsWorld
  def account_ids
    @account_ids ||= {}
  end

  def remember_account(name, account_id)
    account_ids[name] = account_id
  end

  def account_id_for(account_name)
    account_ids.fetch(account_name) { raise "unknown account #{account_name.inspect} — create it first" }
  end

  def create_account(owner_name, account_name)
    result = Accounts::CreateAccount.call(name: account_name, owner_user_id: user_id_for(owner_name))
    raise "could not create account #{account_name}: #{result.error}" if result.failure?

    remember_account(account_name, result.value)
    result.value
  end

  # Creates an account through the real UI (the actor must already be
  # signed in). Remembers the page's account name for later assertions.
  def create_account_via_ui(account_name)
    @last_account_name = account_name
    visit "/accounts/new"
    fill_in "Name", with: account_name
    submit_form "Create account"
  end

  # Looks up the id of an account created through the UI (AccountCreated
  # events carry no name tag, so scan by name).
  def find_account_id(account_name)
    query = DcbEventStore::Query.new([ DcbEventStore::QueryItem.new(event_types: %w[AccountCreated]) ])
    EventStore.read(query).find { |event| event.data[:name] == account_name }&.data&.fetch(:account_id)
  end

  def member_of?(user_name, account_name)
    Accounts::Membership.member?(account_id: account_id_for(account_name), user_id: user_id_for(user_name))
  end

  # Establishes membership through the domain (owner invites, user accepts)
  # so the same phrase works as a Given. No-op when already a member.
  def ensure_member(user_name, account_name)
    return if member_of?(user_name, account_name)

    account_id = account_id_for(account_name)
    email = users.fetch(user_name).fetch(:email)
    invitation = Accounts::InvitePlayer.call(account_id:, email:, invited_by_user_id: account_owner_id(account_id))
    raise "could not invite #{user_name}: #{invitation.error}" if invitation.failure?

    accept_invitation(invitation.value, user_name, email)
  end

  def accept_invitation(invitation_id, user_name, email)
    result = Accounts::AcceptInvitation.call(invitation_id:, user_id: user_id_for(user_name), user_email: email)
    raise "#{user_name} could not accept the invitation: #{result.error}" if result.failure?
  end

  def account_owner_id(account_id)
    Accounts::Account.find(account_id)&.owner_user_id or raise "account #{account_id} does not exist"
  end

  # Invites through the real UI; the inviter must be able to sign in.
  def invite(inviter_name, email, account_name)
    sign_in(inviter_name) unless signed_in_as?(inviter_name)
    visit "/accounts/#{account_id_for(account_name)}/invitations/new"
    fill_in "Email", with: email
    submit_form "Send invitation"
  end

  def latest_invitation_id(account_name)
    query = DcbEventStore::Query.new([
      DcbEventStore::QueryItem.new(event_types: %w[PlayerInvited], tags: [ "account:#{account_id_for(account_name)}" ])
    ])
    EventStore.read(query).last&.data&.fetch(:invitation_id) or
      raise "no invitation to #{account_name.inspect} found"
  end

  def pending_invitation_account_ids(email)
    Accounts::PendingInvitations.for_email(email).map(&:account_id)
  end
end

World(AccountsWorld)
