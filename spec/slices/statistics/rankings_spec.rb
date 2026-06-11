require "rails_helper"

RSpec.describe Statistics::Rankings do
  def names
    { "a" => "Alice", "b" => "Bob", "c" => "Carol", "d" => "Dave" }
  end

  describe ".order" do
    it "orders by points descending" do
      expect(described_class.order(points: { "a" => 990, "b" => 1010 }, names:)).to eq(%w[b a])
    end

    it "orders tied players alphabetically by name" do
      expect(described_class.order(points: { "d" => 1000, "b" => 1000, "c" => 1000 }, names:))
        .to eq(%w[b c d])
    end

    it "breaks ties by name even when the ids sort the other way" do
      tied = { "a-id" => 1000, "z-id" => 1000 }
      expect(described_class.order(points: tied, names: { "a-id" => "Zoe", "z-id" => "Anna" }))
        .to eq(%w[z-id a-id])
    end

    it "falls back to the player id when no name is known" do
      expect(described_class.order(points: { "b-id" => 1000, "a-id" => 1000 }, names: {}))
        .to eq(%w[a-id b-id])
    end
  end

  describe ".rank_of" do
    it "ranks the points leader first" do
      expect(described_class.rank_of("b", points: { "a" => 990, "b" => 1010 }, names:)).to eq(1)
    end

    it "ranks the runner-up second" do
      expect(described_class.rank_of("a", points: { "a" => 990, "b" => 1010 }, names:)).to eq(2)
    end

    it "gives tied players sequential ranks in name order" do
      points = { "d" => 1000, "b" => 1000, "c" => 1100 }
      expect(described_class.rank_of("c", points:, names:)).to eq(1)
      expect(described_class.rank_of("b", points:, names:)).to eq(2)
      expect(described_class.rank_of("d", points:, names:)).to eq(3)
    end

    it "is nil for a player without a balance" do
      expect(described_class.rank_of("ghost", points: { "a" => 1000 }, names:)).to be_nil
    end
  end
end
