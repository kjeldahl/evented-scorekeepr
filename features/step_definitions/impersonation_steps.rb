# frozen_string_literal: true

# Impersonation slice steps (docs/DOMAIN.md § Impersonation). Helpers live in
# features/support/impersonation_world.rb. The impersonate button sits on the
# accounts members list; the notice + escape button live in the shared layout,
# so notice/escape assertions just visit any page.

Then("{string} sees an impersonate button for the member {string} in the {string} account") \
do |viewer, member_name, account_name|
  sign_in(viewer) unless signed_in_as?(viewer)
  visit "/accounts/#{account_id_for(account_name)}"
  within("table.members tr", text: member_name) do
    expect(page).to have_button("Impersonate")
  end
end

Then("{string} sees no impersonate button for the member {string} in the {string} account") \
do |viewer, member_name, account_name|
  sign_in(viewer) unless signed_in_as?(viewer)
  visit "/accounts/#{account_id_for(account_name)}"
  within("table.members tr", text: member_name) do
    expect(page).to have_no_button("Impersonate")
  end
end

Then("{string} sees no impersonate button in the {string} account") do |viewer, account_name|
  sign_in(viewer) unless signed_in_as?(viewer)
  visit "/accounts/#{account_id_for(account_name)}"
  expect(page).to have_css("table.members")
  expect(page).to have_no_button("Impersonate")
end

# Works as a Given (establish an in-effect session) and a When (act now).
When("{string} impersonates the member {string} in the {string} account") do |super_admin, member_name, account_name|
  impersonate(super_admin, member_name, account_name)
end

When("{string} attempts to impersonate the member {string} in the {string} account") do |actor, member_name, account_name|
  impersonate(actor, member_name, account_name)
end

Then("the impersonation is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

# The notice lives in the layout, so any page shows it. The acting session is
# already the super admin's — do not sign in (the nav shows the member).
Then("{string} sees a notice that they are impersonating {string}") do |_viewer, member_name|
  visit "/"
  expect(page).to have_css(".impersonation-banner", text: member_name)
end

Then("{string} still sees a notice that they are impersonating {string}") do |_viewer, member_name|
  visit "/"
  expect(page).to have_css(".impersonation-banner", text: member_name)
end

Then("{string} sees a button to stop impersonating") do |_viewer|
  visit "/"
  expect(page).to have_button("Stop impersonating")
end

When("{string} stops impersonating") do |_name|
  stop_impersonating
end

Then("{string} sees no impersonation notice") do |_viewer|
  visit "/"
  expect(page).to have_no_css(".impersonation-banner")
end

Then("the audit trail records that {string} started impersonating {string}") do |super_admin, member|
  starts = audit_events("ImpersonationStarted", super_admin)
  expect(starts.map { |event| event.data.fetch(:impersonated_user_id) }).to include(user_id_for(member))
end

Then("the audit trail records that {string} stopped impersonating {string}") do |super_admin, member|
  started = audit_events("ImpersonationStarted", super_admin)
             .find { |event| event.data.fetch(:impersonated_user_id) == user_id_for(member) } or
    raise "no impersonation of #{member.inspect} by #{super_admin.inspect} was started"
  ended_ids = audit_events("ImpersonationEnded", super_admin).map { |event| event.data.fetch(:impersonation_id) }
  expect(ended_ids).to include(started.data.fetch(:impersonation_id))
end

Then("the audit trail records that {string} impersonating {string} registered a match in {string}") \
do |super_admin, member, league|
  records = audit_events("ImpersonatedActionRecorded", super_admin).select do |event|
    event.data.fetch(:impersonated_user_id) == user_id_for(member)
  end
  matches = records.select do |event|
    event.data.fetch(:actions).any? do |action|
      action.fetch(:type) == "MatchRegistered" && action.fetch(:tags).include?("league:#{league_id_for(league)}")
    end
  end
  expect(matches).not_to be_empty
end
