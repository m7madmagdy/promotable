# Promotable

An extensible promotion and coupon engine for Ruby on Rails 8+. Promotable provides a type-agnostic, pluggable promotion system that you can attach to **any** model -- orders, carts, subscriptions, bookings -- without modifying the gem itself.

**Key design goals:** extensibility through STI-based rules/actions, a thread-safe registry for custom types, and clean host-app integration via `acts_as_promotable` / `acts_as_promoter` concerns.

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Setup](#setup)
- [Core Concepts](#core-concepts)
- [Usage](#usage)
  - [Applying a Coupon Code](#applying-a-coupon-code)
  - [Auto-Applying Promotions](#auto-applying-the-best-available-promotions)
  - [Checking Discounts](#checking-the-discount-total)
  - [Removing Promotions](#removing-promotions)
  - [Creating Promotions Programmatically](#creating-a-promotion-programmatically)
  - [Batch Code Generation](#batch-code-generation)
  - [Querying Promotions](#querying-promotions)
  - [Querying Adjustments](#querying-adjustments)
  - [Using the Services Directly](#using-the-services-directly)
  - [Rake Tasks](#rake-tasks)
- [Built-in Rules](#built-in-rules)
- [Built-in Actions](#built-in-actions)
- [Creating Custom Rules](#creating-custom-rules)
- [Creating Custom Actions](#creating-custom-actions)
- [Configuration](#configuration)
- [Error Handling](#error-handling)
- [Database Schema](#database-schema)
- [Generators](#generators)
- [Testing](#testing)
  - [Running the Gem Test Suite](#running-the-gem-test-suite)
  - [Testing in Your Host App](#testing-in-your-host-app)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [License](#license)

## Requirements

- Ruby >= 3.2
- Rails >= 8.0
- A relational database supported by ActiveRecord (PostgreSQL, MySQL, SQLite)

## Installation

**From a local path** (during development):

```ruby
# Gemfile
gem "promotable", path: "../promotable"
```

**From a Git repository**:

```ruby
# Gemfile
gem "promotable", git: "https://github.com/your-org/promotable.git", branch: "main"
```

**From RubyGems** (once published):

```ruby
# Gemfile
gem "promotable"
```

Then install and set up:

```bash
bundle install
rails generate promotable:install
rails db:migrate
```

The install generator does two things:

1. Copies the migration file into your app's `db/migrate/` directory.
2. Creates a configuration initializer at `config/initializers/promotable.rb`.

## Setup

### 1. Mark your promotable model

Any model that can *receive* promotions (e.g. Order, Cart, Subscription) calls `acts_as_promotable` and implements the `#promotable_amount` method:

```ruby
class Order < ApplicationRecord
  acts_as_promotable

  # REQUIRED -- return the base amount before discounts as a BigDecimal.
  def promotable_amount
    BigDecimal(total_price.to_s)
  end

  # OPTIONAL -- return an array-like collection of line items.
  # Only needed if you use ItemQuantityRule.
  def promotable_items
    line_items
  end

  # OPTIONAL -- return the shipping cost as a BigDecimal.
  # Only needed if you use FreeShippingDiscount.
  def promotable_shipping_cost
    BigDecimal(shipping_total.to_s)
  end
end
```

This gives your model:

| Method | Description |
|---|---|
| `apply_promotion_code(code, user:)` | Redeem a coupon code on this record. |
| `apply_best_promotions(user:)` | Auto-apply all eligible promotions. |
| `remove_all_promotions` | Remove every adjustment from this record. |
| `recalculate_promotions(user:)` | Remove then re-apply eligible promotions. |
| `promotion_total_discount` | Sum of all eligible adjustment amounts (negative = discount). |
| `active_promotions` | Array of distinct `Promotable::Promotion` records currently applied. |
| `promotable_adjustments` | ActiveRecord association of `Promotable::Adjustment` records. |
| `promotable_code_usages` | ActiveRecord association of `Promotable::CodeUsage` records. |

### 2. Mark your user model

Any model that *redeems* promotions calls `acts_as_promoter`:

```ruby
class User < ApplicationRecord
  acts_as_promoter

  # OPTIONAL -- return a group string for UserEligibilityRule.
  def promotion_group
    vip? ? "vip" : "regular"
  end
end
```

This gives your model:

| Method | Description |
|---|---|
| `promotion_usage_count(promotion)` | How many times this user has used a given promotion. |
| `used_promotion?(promotion)` | Whether this user has used the promotion at all. |
| `available_promotions` | All active promotions this user is still eligible for. |
| `promotion_code_usages` | ActiveRecord association of `Promotable::CodeUsage` records. |

### 3. Configure (optional)

Edit `config/initializers/promotable.rb` to customize behavior and register custom types. See the [Configuration](#configuration) section for all options.

## Core Concepts

| Concept | Model | Description |
|---|---|---|
| **Promotion** | `Promotable::Promotion` | The central entity: a named promotion with date range, usage limits, priority, and stacking rules. |
| **Rule** | `Promotable::Rules::Base` | An eligibility condition (STI). All rules on a promotion must pass for it to apply. |
| **Action** | `Promotable::Actions::Base` | A discount behavior (STI). Each action creates an `Adjustment` when applied. |
| **PromotionCode** | `Promotable::PromotionCode` | A redeemable coupon code string linked to a promotion, with its own usage limit. |
| **Adjustment** | `Promotable::Adjustment` | A polymorphic record tracking an applied discount on any promotable. |
| **CodeUsage** | `Promotable::CodeUsage` | Tracks who used which code on which promotable, enabling per-user limits. |

### How it works

```
1.  User enters a coupon code (or promotions are auto-applied)
         |
2.  CodeRedeemer validates the code, promotion status, and usage limits
         |
3.  Evaluator checks all Rules on the promotion against the promotable
         |
4.  Applicator executes each Action in a transaction, creating Adjustment records
         |
5.  PromotionCode and Promotion usage counts are incremented
         |
6.  CodeUsage is recorded for per-user tracking
```

## Usage

### Applying a coupon code

```ruby
order = Order.find(params[:id])
user  = current_user

begin
  promotion = order.apply_promotion_code("SAVE20", user: user)
  # promotion is the Promotable::Promotion that was applied
rescue Promotable::InvalidCodeError => e
  # Code not found
rescue Promotable::PromotionInactiveError => e
  # Promotion is not active
rescue Promotable::PromotionExpiredError => e
  # Promotion has expired or hasn't started yet
rescue Promotable::UsageLimitExceededError => e
  # Code, promotion, or per-user usage limit reached
rescue Promotable::IneligibleError => e
  # Promotion rules not satisfied
end
```

### Auto-applying the best available promotions

```ruby
order.apply_best_promotions(user: current_user)
```

This finds all eligible promotions, sorts them by priority, respects stacking rules, and applies them within the configured `max_promotions_per_promotable` limit.

### Checking the discount total

```ruby
order.promotion_total_discount  # => BigDecimal("-15.0")
order.active_promotions         # => [#<Promotable::Promotion name: "Summer Sale", ...>]
```

### Removing promotions

```ruby
# Remove all adjustments
order.remove_all_promotions

# Remove then re-apply from scratch
order.recalculate_promotions(user: current_user)
```

### Creating a promotion programmatically

```ruby
promo = Promotable::Promotion.create!(
  name:           "Summer Sale",
  description:    "20% off orders over $50",
  active:         true,
  starts_at:      Date.new(2026, 6, 1),
  expires_at:     Date.new(2026, 8, 31),
  usage_limit:    1000,
  per_user_limit: 1,
  priority:       0,
  stackable:      false,
  metadata:       { campaign: "summer_2026" }
)

# Add eligibility rules
promo.rules.create!(
  type: "Promotable::Rules::MinimumAmountRule",
  preferences: { minimum_amount: 50 }
)

# Add discount actions
promo.actions.create!(
  type: "Promotable::Actions::PercentageDiscount",
  preferences: { percentage: 20 }
)

# Create a coupon code
promo.codes.create!(code: "SUMMER20", usage_limit: 500)
```

#### Promotion fields reference

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | *required* | Display name of the promotion. |
| `description` | `text` | `nil` | Human-readable description. |
| `promotion_type` | `string` | `nil` | Free-form label for categorization. |
| `starts_at` | `datetime` | `nil` | When the promotion becomes valid. `nil` = immediately. |
| `expires_at` | `datetime` | `nil` | When the promotion expires. `nil` = never. |
| `usage_limit` | `integer` | `nil` | Max total redemptions. `nil` = unlimited. |
| `per_user_limit` | `integer` | `nil` | Max redemptions per user. `nil` = unlimited. |
| `usage_count` | `integer` | `0` | Current total redemptions (auto-incremented). |
| `active` | `boolean` | `false` | Master on/off switch. |
| `priority` | `integer` | `0` | Lower = applied first. |
| `stackable` | `boolean` | `true` | Whether this can combine with other promotions. |
| `metadata` | `json` | `{}` | Arbitrary key-value data for your application. |

### Batch code generation

A single promotion can have many codes for campaigns:

```ruby
promo = Promotable::Promotion.find(1)

100.times do |i|
  promo.codes.create!(
    code: "BATCH-#{SecureRandom.alphanumeric(8).upcase}",
    usage_limit: 1
  )
end

# Query available codes
Promotable::PromotionCode.available  # codes that haven't hit their usage limit
```

### Querying promotions

```ruby
# Scopes on Promotable::Promotion
Promotable::Promotion.active        # active flag is true
Promotable::Promotion.inactive      # active flag is false
Promotable::Promotion.current       # within date range (or no dates set)
Promotable::Promotion.available     # active + current, ordered by priority
Promotable::Promotion.stackable     # stackable flag is true
Promotable::Promotion.by_priority   # ordered by priority ascending

# Instance checks
promo.eligible?(order, user: user)  # full eligibility check
promo.expired?                      # past expires_at
promo.started?                      # at or past starts_at
promo.within_date_range?            # started and not expired
promo.within_usage_limit?           # under the total usage cap
promo.within_per_user_limit?(user)  # under the per-user cap

# From the user side
user.used_promotion?(promo)         # => true/false
user.promotion_usage_count(promo)   # => 2
user.available_promotions           # promotions the user can still use
```

### Querying adjustments

```ruby
# Scopes on Promotable::Adjustment
Promotable::Adjustment.eligible              # currently active adjustments
Promotable::Adjustment.ineligible            # disabled adjustments
Promotable::Adjustment.credits               # negative amounts (discounts)
Promotable::Adjustment.debits                # positive amounts (surcharges)
Promotable::Adjustment.for_promotable(order) # adjustments for a specific record

# Instance checks
adjustment.credit?  # => true if amount is negative
adjustment.debit?   # => true if amount is positive
```

### Using the services directly

The three service objects can be used independently for advanced workflows:

```ruby
# Evaluator -- find eligible promotions
evaluator = Promotable::Evaluator.new(order, user: user, code: "SAVE20")
evaluator.eligible_promotions  # => [promotion, ...]
evaluator.best_promotion       # => highest-priority eligible promotion

# Applicator -- apply/remove promotions with stacking control
applicator = Promotable::Applicator.new(order, user: user)
applicator.apply(promotions)          # apply multiple, respecting limits
applicator.apply_single(promotion)    # apply one, raises if ineligible
applicator.remove(promotion)          # undo a specific promotion
applicator.remove_all                 # destroy all adjustments

# CodeRedeemer -- end-to-end coupon redemption in a transaction
redeemer = Promotable::CodeRedeemer.new("SAVE20", promotable: order, user: user)
promotion = redeemer.redeem  # validates, applies, records usage, returns promotion
```

### Rake tasks

```bash
# Show registered rules, actions, and promotion counts
rails promotable:stats
```

## Built-in Rules

Rules are eligibility conditions. **All** rules on a promotion must pass for it to apply.

### MinimumAmountRule

Requires the promotable's `#promotable_amount` to meet a threshold.

```ruby
promo.rules.create!(
  type: "Promotable::Rules::MinimumAmountRule",
  preferences: { minimum_amount: 50.0 }
)
```

### ItemQuantityRule

Requires the promotable's `#promotable_items` count to meet a threshold.

```ruby
promo.rules.create!(
  type: "Promotable::Rules::ItemQuantityRule",
  preferences: { minimum_quantity: 3 }
)
```

### FirstPurchaseRule

Eligible only if the user has zero prior code usages. Requires `user` in context.

```ruby
promo.rules.create!(type: "Promotable::Rules::FirstPurchaseRule")
```

### UserEligibilityRule

Eligible only if the user's `#promotion_group` matches. Requires `user` in context.

```ruby
promo.rules.create!(
  type: "Promotable::Rules::UserEligibilityRule",
  preferences: { eligible_group: "vip" }
)
```

## Built-in Actions

Actions define the discount to apply when a promotion is eligible.

### PercentageDiscount

Applies X% off the `#promotable_amount`.

```ruby
promo.actions.create!(
  type: "Promotable::Actions::PercentageDiscount",
  preferences: { percentage: 15 }
)
```

### FixedAmountDiscount

Applies a flat discount. Automatically capped so the discount never exceeds the promotable amount.

```ruby
promo.actions.create!(
  type: "Promotable::Actions::FixedAmountDiscount",
  preferences: { amount: 10.0 }
)
```

### FreeShippingDiscount

Negates the `#promotable_shipping_cost`. No preferences needed.

```ruby
promo.actions.create!(type: "Promotable::Actions::FreeShippingDiscount")
```

## Creating Custom Rules

### Using the generator

```bash
rails generate promotable:rule LoyaltyTier required_tier:integer
```

This creates `app/models/loyalty_tier_rule.rb` and `test/models/loyalty_tier_rule_test.rb`.

### Manual creation

Subclass `Promotable::Rules::Base` and implement the private `#evaluate` method. Optionally override `#pre_check` for fast-fail guards.

```ruby
class LoyaltyTierRule < Promotable::Rules::Base
  store_accessor :preferences, :required_tier

  def self.preference_fields
    [{ name: :required_tier, type: :integer, default: 1 }]
  end

  private

  def pre_check(_promotable, context)
    context[:user].present? && context[:user].respond_to?(:loyalty_tier)
  end

  def evaluate(_promotable, context = {})
    context[:user].loyalty_tier >= required_tier.to_i
  end
end
```

Register it in your initializer:

```ruby
# config/initializers/promotable.rb
Promotable.configure do |config|
  config.rule_registry.register(:loyalty_tier, LoyaltyTierRule)
end
```

Then use it on a promotion:

```ruby
promo.rules.create!(
  type: "LoyaltyTierRule",
  preferences: { required_tier: 3 }
)
```

### Rule API contract

| Method | Visibility | Must implement? | Description |
|---|---|---|---|
| `#eligible?(promotable, context)` | public | No (inherited) | Entry point. Calls `pre_check` then `evaluate`. |
| `#pre_check(promotable, context)` | private | Optional | Fast-fail guard. Return `false` to skip `evaluate`. Defaults to `true`. |
| `#evaluate(promotable, context)` | private | **Yes** | Return `true` if the promotable meets this rule's criteria. |
| `.preference_fields` | public (class) | Optional | Returns an array of hashes describing configurable preferences. |

## Creating Custom Actions

### Using the generator

```bash
rails generate promotable:action BonusPoints points:integer
```

### Manual creation

Subclass `Promotable::Actions::Base` and implement `#compute_amount` and `#apply`. The inherited `#undo` and `#create_adjustment` handle cleanup and persistence.

```ruby
class BuyOneGetOneAction < Promotable::Actions::Base
  def self.preference_fields
    []
  end

  def compute_amount(promotable, _context = {})
    items = promotable.promotable_items
    return BigDecimal("0") if items.size < 2

    cheapest = items.min_by(&:price)
    -BigDecimal(cheapest.price.to_s)
  end

  def apply(promotable, context = {})
    discount = compute_amount(promotable, context)
    return if discount.zero?

    create_adjustment(promotable, discount, label: "Buy one get one free")
  end
end
```

Register it:

```ruby
Promotable.configure do |config|
  config.action_registry.register(:bogo, BuyOneGetOneAction)
end
```

### Action API contract

| Method | Visibility | Must implement? | Description |
|---|---|---|---|
| `#apply(promotable, context)` | public | **Yes** | Execute the discount. Call `create_adjustment` to persist. |
| `#compute_amount(promotable, context)` | public | **Yes** | Return the discount as a negative `BigDecimal`. |
| `#undo(promotable, context)` | public | No (inherited) | Removes adjustments for the promotable. Override for custom cleanup. |
| `.preference_fields` | public (class) | Optional | Array of hashes describing configurable preferences. |
| `#create_adjustment(promotable, amount, label:)` | private (inherited) | N/A | Helper to create an `Adjustment` record. |
| `#remove_adjustments(promotable)` | private (inherited) | N/A | Helper to destroy this action's adjustments for a promotable. |

## Configuration

The initializer at `config/initializers/promotable.rb` supports these options:

```ruby
Promotable.configure do |config|
  # Maximum promotions that can be applied to a single promotable.
  # Default: 5
  config.max_promotions_per_promotable = 5

  # Whether multiple promotions can stack on the same promotable.
  # When false, only the highest-priority promotion is applied.
  # Default: true
  config.allow_stacking = true

  # Whether promotion codes are case-sensitive.
  # When false, "save20" and "SAVE20" are treated as the same code.
  # Default: false
  config.code_case_sensitive = false

  # Register custom rules
  config.rule_registry.register(:loyalty_tier, LoyaltyTierRule)
  config.rule_registry.register(:geo_location, GeoLocationRule)

  # Register custom actions
  config.action_registry.register(:bogo, BuyOneGetOneAction)
  config.action_registry.register(:bonus_points, BonusPointsAction)
end
```

### Resetting configuration

```ruby
Promotable.reset_configuration!
```

### Promotable interface contract

Models using `acts_as_promotable` **must** implement:

| Method | Return type | Required by |
|---|---|---|
| `#promotable_amount` | `BigDecimal` | All rules and actions. Raises `PromotableInterfaceError` if missing. |

Models using `acts_as_promotable` **may** implement:

| Method | Return type | Required by |
|---|---|---|
| `#promotable_items` | Array-like | `ItemQuantityRule` |
| `#promotable_shipping_cost` | `BigDecimal` | `FreeShippingDiscount` |

Models using `acts_as_promoter` **may** implement:

| Method | Return type | Required by |
|---|---|---|
| `#promotion_group` | `String` | `UserEligibilityRule` |

## Error Handling

All errors inherit from `Promotable::Error`, so you can rescue broadly or specifically:

| Error | Raised when |
|---|---|
| `Promotable::InvalidCodeError` | Promotion code string not found in the database. |
| `Promotable::IneligibleError` | Promotion exists but fails eligibility checks. |
| `Promotable::PromotionInactiveError` | Promotion's `active` flag is `false`. |
| `Promotable::PromotionExpiredError` | Promotion is outside its `starts_at..expires_at` range. |
| `Promotable::UsageLimitExceededError` | Code, promotion, or per-user usage limit reached. |
| `Promotable::StackingNotAllowedError` | Stacking is disabled and a promotion is already applied. |
| `Promotable::MaxPromotionsExceededError` | `max_promotions_per_promotable` limit reached. |
| `Promotable::PromotableInterfaceError` | Model does not implement a required interface method (e.g. `#promotable_amount`). |

### Usage in controllers

```ruby
class CouponsController < ApplicationController
  def create
    order = current_user.orders.find(params[:order_id])
    promotion = order.apply_promotion_code(params[:code], user: current_user)

    render json: {
      promotion: promotion.name,
      discount: order.promotion_total_discount.to_f
    }
  rescue Promotable::InvalidCodeError
    render json: { error: "Invalid promotion code" }, status: :not_found
  rescue Promotable::PromotionInactiveError, Promotable::PromotionExpiredError
    render json: { error: "This promotion is no longer available" }, status: :gone
  rescue Promotable::UsageLimitExceededError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Promotable::IneligibleError
    render json: { error: "Your order does not qualify for this promotion" }, status: :unprocessable_entity
  end
end
```

### Catch-all

```ruby
rescue Promotable::Error => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

## Database Schema

Promotable creates six tables, all prefixed with `promotable_`:

| Table | Purpose |
|---|---|
| `promotable_promotions` | Core promotion records with dates, limits, priority, stacking. |
| `promotable_rules` | STI-based eligibility rules. `type` column resolves the subclass. |
| `promotable_actions` | STI-based discount actions. `type` column resolves the subclass. |
| `promotable_promotion_codes` | Redeemable coupon code strings with per-code usage limits. |
| `promotable_code_usages` | Polymorphic join tracking which user used which code on which promotable. |
| `promotable_adjustments` | Polymorphic discount records attached to any promotable model. |

All `preferences` and `metadata` columns use the `json` type for cross-database compatibility (PostgreSQL, MySQL, SQLite).

Indexes are added on `active`, `priority`, `starts_at + expires_at`, `type` (rules/actions), `code` (unique), and `eligible` (adjustments).

## Generators

### Install

```bash
rails generate promotable:install
```

Copies the migration into your app and creates `config/initializers/promotable.rb`.

### Custom Rule

```bash
rails generate promotable:rule RuleName field_name:type field_name:type
```

Creates a rule subclass with `store_accessor` for each field and a matching test file.

### Custom Action

```bash
rails generate promotable:action ActionName field_name:type field_name:type
```

Creates an action subclass with `store_accessor` for each field and a matching test file.

## Testing

### Running the gem test suite

```bash
cd promotable
bundle install
bundle exec rake test
```

The gem ships with 90 tests covering:

- **Model tests** -- Promotion, PromotionCode, Adjustment, all Rule subclasses, all Action subclasses
- **Service tests** -- Evaluator, Applicator, CodeRedeemer
- **Registry tests** -- registration, resolution, validation, thread safety
- **Configuration tests** -- defaults, DSL, reset
- **Integration tests** -- full flows using a dummy Rails app with Order and User models

### Testing in your host app

When writing tests that involve promotions in your application:

```ruby
class OrderPromotionTest < ActiveSupport::TestCase
  setup do
    @promo = Promotable::Promotion.create!(
      name: "Test Promo",
      active: true,
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now
    )
    @promo.actions.create!(
      type: "Promotable::Actions::FixedAmountDiscount",
      preferences: { amount: 10 }
    )
    @promo.codes.create!(code: "TEST10")

    @order = Order.create!(total_price: 100)
    @user  = User.create!(name: "Tester")
  end

  test "applying a coupon code creates an adjustment" do
    @order.apply_promotion_code("TEST10", user: @user)

    assert_equal BigDecimal("-10"), @order.promotion_total_discount
    assert_equal 1, @order.promotable_adjustments.count
  end

  test "invalid code raises InvalidCodeError" do
    assert_raises Promotable::InvalidCodeError do
      @order.apply_promotion_code("NOPE", user: @user)
    end
  end
end
```

## Architecture

For a deep dive into the internal design -- design patterns (Strategy, Template Method, Registry), data model ER diagrams, service layer sequence diagrams, and extension points -- see [ARCHITECTURE.md](ARCHITECTURE.md).

## Contributing

### Getting started

1. Fork the repository and clone your fork.
2. Install dependencies:

```bash
cd promotable
bundle install
```

3. Set up the test database:

```bash
cd test/dummy
RAILS_ENV=test bin/rails db:create db:migrate
cd ../..
```

4. Run the test suite to confirm everything passes:

```bash
bundle exec rake test
```

### Development workflow

- The gem uses a **dummy Rails app** at `test/dummy/` for integration testing. It contains `Order` and `User` models that use `acts_as_promotable` and `acts_as_promoter`.
- Source code lives in `app/models/promotable/` (models) and `lib/promotable/` (services, concerns, infrastructure).
- Tests mirror the source structure under `test/`.

### Making changes

1. Create a feature branch from `main`:

```bash
git checkout -b feature/my-improvement
```

2. Write your code. Follow existing patterns:
   - New rules go in `app/models/promotable/rules/` and subclass `Rules::Base`.
   - New actions go in `app/models/promotable/actions/` and subclass `Actions::Base`.
   - New services go in `lib/promotable/`.
   - New configuration options go in `lib/promotable/configuration.rb`.

3. Add tests for every new feature or bug fix. The test suite must pass:

```bash
bundle exec rake test
```

4. Make sure there are no Ruby warnings in the test output.

5. Commit and push your branch, then open a pull request.

### Code guidelines

- **No monkey-patching** of core Ruby classes.
- **Use STI** for new rule or action types -- do not add conditional logic to the base classes.
- **Store runtime configuration** in the `preferences` JSON column via `store_accessor`, not as new database columns.
- **Keep services stateless** -- instantiate per request, do not cache state between calls.
- **Use `BigDecimal`** for all monetary calculations, never `Float`.
- **Return meaningful errors** -- raise a specific `Promotable::Error` subclass with a descriptive message.
- All public methods should be covered by tests.

### Adding a new built-in rule

1. Create `app/models/promotable/rules/my_rule.rb` inheriting from `Rules::Base`.
2. Implement `#evaluate` (required) and optionally `#pre_check`.
3. Add `self.preference_fields` if the rule has configuration.
4. Register it in `Configuration#register_defaults!`.
5. Add tests in `test/models/promotable/rules/my_rule_test.rb`.

### Adding a new built-in action

1. Create `app/models/promotable/actions/my_action.rb` inheriting from `Actions::Base`.
2. Implement `#compute_amount` and `#apply`.
3. Add `self.preference_fields` if the action has configuration.
4. Register it in `Configuration#register_defaults!`.
5. Add tests in `test/models/promotable/actions/my_action_test.rb`.

### Reporting issues

- Use the GitHub issue tracker.
- Include your Ruby version, Rails version, database adapter, and the full error backtrace.
- If possible, provide a minimal reproduction case.

## Changelog

All notable changes are documented in [CHANGELOG.md](CHANGELOG.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
