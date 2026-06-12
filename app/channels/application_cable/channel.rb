module ApplicationCable
  # Shared base class for slice channels (root package — web infrastructure
  # like ApplicationController). Slice channels live in their slice's web/
  # directory and enforce the same gates as the slice's controllers.
  class Channel < ActionCable::Channel::Base
  end
end
