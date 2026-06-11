# frozen_string_literal: true

# Accounts slice steps. Account helpers (account_ids registry,
# create_account, ensure_member, invite, latest_invitation_id, ...) live in
# features/support/accounts_world.rb so later slices can reuse the shared
# phrases ("X owns the Y account", "X is a member of the Y account",
# "X cannot see the Y account").

Given("{string} owns the {string} account") do |owner_name, account_name|
  create_account(owner_name, account_name)
end

When("{string} creates an account named {string}") do |_name, account_name|
  create_account_via_ui(account_name)
  remember_account(account_name, find_account_id(account_name) || raise("account was not created"))
end

When("{string} attempts to create an account named {string}") do |_name, account_name|
  create_account_via_ui(account_name)
end

When("someone who is not signed in attempts to create an account named {string}") do |_account_name|
  visit "/accounts/new"
end

Then("the account creation is accepted") do
  expect(page).to have_css(".flash--notice")
  expect(page).to have_css("h1", text: @last_account_name)
end

Then("the account creation is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

Then("{string} is the owner of the {string} account") do |name, account_name|
  account = Accounts::Account.find(account_id_for(account_name))
  expect(account.owner_user_id).to eq(user_id_for(name))
end

# Used both as a Given (establish membership via the domain) and as a Then
# (assert it). ensure_member is a no-op when already a member.
Given("{string} is a member of the {string} account") do |name, account_name|
  ensure_member(name, account_name)
  expect(member_of?(name, account_name)).to be(true)
end

Then("{string} is not a member of the {string} account") do |name, account_name|
  expect(member_of?(name, account_name)).to be(false)
end

When("{string} invites {string} to the {string} account") do |inviter_name, email, account_name|
  invite(inviter_name, email, account_name)
end

When("{string} attempts to invite {string} to the {string} account") do |inviter_name, email, account_name|
  sign_in(inviter_name) unless signed_in_as?(inviter_name)
  page.driver.submit :post, "/accounts/#{account_id_for(account_name)}/invitations", { email: }
end

Then("the invitation is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

Then("{string} has a pending invitation to the {string} account") do |email, account_name|
  expect(pending_invitation_account_ids(email)).to include(account_id_for(account_name))
end

Then("{string} has no pending invitation to the {string} account") do |email, account_name|
  expect(pending_invitation_account_ids(email)).not_to include(account_id_for(account_name))
end

Then("{string} sees a pending invitation to the {string} account") do |name, account_name|
  expect_signed_in_as(name)
  visit "/"
  expect(page).to have_css(".invitation-list li", text: account_name)
  expect(page).to have_button("Accept")
end

When("{string} accepts the invitation to the {string} account") do |name, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/invitations"
  within(".invitation-list li", text: account_name) { click_button "Accept" }
end

When("{string} attempts to accept the invitation to the {string} account") do |name, account_name|
  sign_in(name) unless signed_in_as?(name)
  page.driver.submit :post, "/invitations/#{latest_invitation_id(account_name)}/accept", {}
end

Then("the invitation acceptance is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

Then("{string} can see the {string} account") do |name, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/accounts/#{account_id_for(account_name)}"
  expect(page).to have_css("h1", text: account_name)
end

Then("{string} cannot see the {string} account") do |name, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/accounts/#{account_id_for(account_name)}"
  expect(page).to have_current_path("/")
  expect(page).to have_css(".flash--alert")
  expect(page).to have_no_css("h1", text: account_name)
end

Then("{string} sees an outgoing invitation to {string} in the {string} account") do |name, email, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/accounts/#{account_id_for(account_name)}"
  expect(page).to have_css(".outgoing-invitations li", text: email)
end

Then("{string} sees no outgoing invitation to {string} in the {string} account") do |name, email, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/accounts/#{account_id_for(account_name)}"
  expect(page).to have_no_css(".outgoing-invitations li", text: email)
end

When("{string} accepts the outgoing invitation to {string} in the {string} account on behalf of the invited player") \
do |name, email, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/accounts/#{account_id_for(account_name)}"
  within(".outgoing-invitations li", text: email) { click_button "Accept on behalf" }
end

When("{string} revokes the invitation to {string} in the {string} account") do |name, email, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/accounts/#{account_id_for(account_name)}"
  within(".outgoing-invitations li", text: email) { click_button "Revoke" }
end

When("{string} attempts to revoke the invitation to {string} in the {string} account") do |name, email, account_name|
  sign_in(name) unless signed_in_as?(name)
  path = "/accounts/#{account_id_for(account_name)}/invitations/#{invitation_id_to(email, account_name)}/revoke"
  page.driver.submit :post, path, {}
end

Then("the invitation revocation is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

When("{string} declines the invitation to the {string} account") do |name, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/invitations"
  within(".invitation-list li", text: account_name) { click_button "Decline" }
end

When("{string} attempts to decline the invitation to the {string} account") do |name, account_name|
  sign_in(name) unless signed_in_as?(name)
  page.driver.submit :post, "/invitations/#{latest_invitation_id(account_name)}/decline", {}
end

Then("the invitation decline is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

When("{string} leaves the {string} account") do |name, account_name|
  sign_in(name) unless signed_in_as?(name)
  visit "/accounts/#{account_id_for(account_name)}"
  click_button "Leave account"
end

Then("{string} sees the member {string} in the {string} account") do |viewer, member_name, account_name|
  sign_in(viewer) unless signed_in_as?(viewer)
  visit "/accounts/#{account_id_for(account_name)}"
  expect(page).to have_css("table.members td", exact_text: member_name)
end

Then("{string} does not see the member {string} in the {string} account") do |viewer, member_name, account_name|
  sign_in(viewer) unless signed_in_as?(viewer)
  visit "/accounts/#{account_id_for(account_name)}"
  expect(page).to have_css("table.members")
  expect(page).to have_no_css("table.members td", exact_text: member_name)
end
