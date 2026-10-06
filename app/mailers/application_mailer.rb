class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Scorekeepr <noreply@example.com>")
  layout "mailer"
end
