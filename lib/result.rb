# frozen_string_literal: true

# Shared result object returned by every slice command's `.call`.
# See docs/ARCHITECTURE.md ("Command pattern").
#
#   Result.success(league_id)          #=> success? true, value league_id
#   Result.failure("League is closed") #=> failure? true, error message
Result = Data.define(:success, :value, :error) do
  def self.success(value = nil)
    new(success: true, value: value, error: nil)
  end

  def self.failure(error)
    new(success: false, value: nil, error: error)
  end

  def success? = success
  def failure? = !success
end
