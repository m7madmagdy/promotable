require "rails_helper"

RSpec.describe Promotable::Registry do
  before do
    @registry = described_class.new(Promotable::Rules::Base)
  end

  it "registers and resolves a rule class" do
    @registry.register(:minimum_amount, Promotable::Rules::MinimumAmountRule)

    expect(@registry.resolve(:minimum_amount)).to eq(Promotable::Rules::MinimumAmountRule)
  end

  it "rejects classes not inheriting from base_class" do
    expect { @registry.register(:bad, String) }.to raise_error(ArgumentError)
  end

  it "raises for unknown key on resolve" do
    expect { @registry.resolve(:nonexistent) }.to raise_error(ArgumentError)
  end

  it "returns true for registered keys" do
    @registry.register(:test, Promotable::Rules::MinimumAmountRule)

    expect(@registry.registered?(:test)).to be(true)
    expect(@registry.registered?(:unknown)).to be(false)
  end

  it "removes a key with unregister" do
    @registry.register(:temp, Promotable::Rules::MinimumAmountRule)
    @registry.unregister(:temp)

    expect(@registry.registered?(:temp)).to be(false)
  end

  it "returns all registered keys" do
    @registry.register(:a, Promotable::Rules::MinimumAmountRule)
    @registry.register(:b, Promotable::Rules::ItemQuantityRule)

    expect(@registry.keys.sort).to eq([ :a, :b ].sort)
  end

  it "returns a hash of all registrations" do
    @registry.register(:x, Promotable::Rules::MinimumAmountRule)

    expect(@registry.all).to eq({ x: Promotable::Rules::MinimumAmountRule })
  end

  it "clears all registrations" do
    @registry.register(:a, Promotable::Rules::MinimumAmountRule)
    @registry.clear!

    expect(@registry.keys).to be_empty
  end
end
