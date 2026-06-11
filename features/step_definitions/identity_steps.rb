# frozen_string_literal: true

# Identity slice steps. Helpers (users registry, sign_up/sign_in/sign_out,
# expect_signed_in_as, ...) live in features/support/world.rb so later
# slices can reuse the shared phrases ("X is a registered user ...",
# "X is signed in").
#
# Note on redirects: successful sign-up/sign-in redirects to root, which the
# accounts slice has not built yet. The world's `submit_form` tolerates that
# missing page (the session cookie is already stored), and the signed-in
# assertions read the layout nav on /signup, which always renders.

Given("{string} is a registered user with email {string} and password {string}") do |name, email, password|
  register_user(name, email:, password:)
end

Given("{string} is a super admin") do |name|
  grant_super_admin(name)
end

When("someone signs up with name {string}, email {string} and password {string}") do |name, email, password|
  @last_actor = name
  sign_up(name, email:, password:)
end

Then("the sign-up is accepted") do
  expect_signed_in_as(@last_actor)
end

Then("the sign-up is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

Then("{string} is a registered user with email {string}") do |name, email|
  data = registered_user_data(email:)
  expect(data).not_to be_nil
  expect(data[:name]).to eq(name)
end

When("{string} signs in with email {string} and password {string}") do |name, email, password|
  @last_actor = name
  visit "/login"
  fill_in "Email", with: email
  fill_in "Password", with: password
  submit_form "Sign in"
end

When("someone signs in with email {string} and password {string}") do |email, password|
  visit "/login"
  fill_in "Email", with: email
  fill_in "Password", with: password
  submit_form "Sign in"
end

Then("the sign-in is accepted") do
  expect_signed_in_as(@last_actor)
end

Then("the sign-in is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end

# Used both as a Given (establish the session) and as a Then (assert it).
# When already signed in as that user it is a pure assertion; otherwise it
# signs them in first. Scenarios that test the sign-in flow itself assert
# acceptance via "the sign-in is accepted" before reaching this step.
Given("{string} is signed in") do |name|
  sign_in(name) unless signed_in_as?(name)
  expect_signed_in_as(name)
end

Then("{string} is not signed in") do |_name|
  expect_signed_out
end

When("{string} signs out") do |_name|
  sign_out
end

When("{string} sets the handle {string}") do |name, handle|
  sign_in(name) unless signed_in_as?(name)
  visit "/profile"
  fill_in "Handle", with: handle
  submit_form "Save handle"
end

When("{string} attempts to set the handle {string}") do |name, handle|
  sign_in(name) unless signed_in_as?(name)
  visit "/profile"
  fill_in "Handle", with: handle
  submit_form "Save handle"
end

Then("the handle change is rejected because {string}") do |reason|
  expect(page).to have_css(".flash--alert", text: reason)
end
