module ApplicationHelper
  # Development conveniences (e.g. accepting an invitation on behalf of the
  # invited player) are routed and rendered outside production only.
  def dev_tools?
    !Rails.env.production?
  end
end
