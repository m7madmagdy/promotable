require "test_helper"

class Promotable::RegistryTest < ActiveSupport::TestCase
  setup do
    @registry = Promotable::Registry.new(Promotable::Rules::Base)
  end

  test "register and resolve a rule class" do
    @registry.register(:minimum_amount, Promotable::Rules::MinimumAmountRule)
    assert_equal Promotable::Rules::MinimumAmountRule, @registry.resolve(:minimum_amount)
  end

  test "register rejects classes not inheriting from base_class" do
    assert_raises ArgumentError do
      @registry.register(:bad, String)
    end
  end

  test "resolve raises for unknown key" do
    assert_raises ArgumentError do
      @registry.resolve(:nonexistent)
    end
  end

  test "registered? returns true for known keys" do
    @registry.register(:test, Promotable::Rules::MinimumAmountRule)
    assert @registry.registered?(:test)
    assert_not @registry.registered?(:unknown)
  end

  test "unregister removes a key" do
    @registry.register(:temp, Promotable::Rules::MinimumAmountRule)
    @registry.unregister(:temp)
    assert_not @registry.registered?(:temp)
  end

  test "keys returns all registered keys" do
    @registry.register(:a, Promotable::Rules::MinimumAmountRule)
    @registry.register(:b, Promotable::Rules::ItemQuantityRule)
    assert_equal [ :a, :b ].sort, @registry.keys.sort
  end

  test "all returns a hash of all registrations" do
    @registry.register(:x, Promotable::Rules::MinimumAmountRule)
    result = @registry.all
    assert_equal({ x: Promotable::Rules::MinimumAmountRule }, result)
  end

  test "clear! removes all registrations" do
    @registry.register(:a, Promotable::Rules::MinimumAmountRule)
    @registry.clear!
    assert_empty @registry.keys
  end
end
