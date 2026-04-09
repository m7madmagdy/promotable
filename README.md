# Promotable

An extensible promotion and coupon engine for Ruby on Rails 8+. Promotable provides a type-agnostic, pluggable promotion system that you can attach to **any** model -- orders, carts, subscriptions, bookings -- without modifying the gem itself.

**Key design goals:** extensibility through STI-based rules/actions, a thread-safe registry for custom types, and clean host-app integration via `acts_as_promotable` / `acts_as_promoter` concerns.

## Table of Contents

- [Installation](#installation)
- [Setup](#setup)
- [Core Concepts](#core-concepts)
- [Usage](#usage)
- [Built-in Rules](#built-in-rules)
- [Built-in Actions](#built-in-actions)
- [Creating Custom Rules](#creating-custom-rules)
- [Creating Custom Actions](#creating-custom-actions)
- [Configuration](#configuration)
- [Error Handling](#error-handling)
- [Testing](#testing)
- [License](#license)

## Installation

Add to your application's Gemfile:

```ruby
gem "promotable", path: "path/to/promotable"
```

Then run the install generator:

```bash
bundle install
rails generate promotable:install
rails db:migrate
```

The generator copies the migration files and creates a configuration initializer at `config/initializers/promotable.rb`.

## Setup

### 1. Mark your promotable model

Any model that can *receive* promotions (e.g. Order, Cart, Subscription) needs `acts_as_promotable` and a `#promotable_amount` method:

```ruby
class Order < ApplicationRecord
  acts_as_promotable

  # Required -- return the base amount before discounts
  def promotable_amount
    BigDecimal(total_price.to_s)
  end

  # Optional -- return an array-like collection of line items
  # (needed only if you use ItemQuantityRule)
  def promotable_items
    line_items
  end

  # Optional -- return the shipping cost
  # (needed only if you use FreeShippingDiscount)
  def promotable_shipping_cost
    BigDecimal(shipping_total.to_s)
  end
end
```

### 2. Mark your user model

Any model that *redeems* promotions needs `acts_as_promoter`:

```ruby
class User < ApplicationRecord
  acts_as_promoter
end
```

## Core Concepts

| Concept | Description |
|---|---|
| **Promotion** | A named promotion with date range, usage limits, priority, and stacking rules. |
| **Rule** | An eligibility condition attached to a promotion. All rules must pass for a promotion to apply. |
| **Action** | A discount behavior that executes when a promotion is applied, creating an adjustment. |
| **PromotionCode** | A redeemable code string linked to a promotion, with its own usage limit. |
| **Adjustment** | A polymorphic record tracking the actual discount amount applied to a promotable. |
| **CodeUsage** | A record of who used which code on which promotable, enabling per-user limits. |

### How it works

```
Coupon Code entered
      |
      v
CodeRedeemer validates the code, promotion status, and limits
      |
      v
Evaluator checks all Rules on the promotion against the promotable
      |
      v
Applicator executes each Action, creating Adjustment records
      |
      v
PromotionCode & Promotion usage counts are incremented
```

## Usage

### Applying a coupon code

```ruby
order = Order.find(params[:id])
user  = current_user

begin
  order.apply_promotion_code("SAVE20", user: user)
rescue Promotable::InvalidCodeError => e
  # code not found
rescue Promotable::PromotionExpiredError => e
  # promotion has expired or hasn't started
rescue Promotable::UsageLimitExceededError => e
  # code, promotion, or per-user limit reached
rescue Promotable::PromotionInactiveError => e
  # promotion is not active
end
```

### Auto-applying the best available promotions

```ruby
order.apply_best_promotions(user: current_user)
```

### Checking the discount total

```ruby
order.promotion_total_discount  # => BigDecimal("-15.0")
order.active_promotions         # => [#<Promotable::Promotion ...>]
```

### Removing promotions

```ruby
order.remove_all_promotions
# or recalculate from scratch:
order.recalculate_promotions(user: current_user)
```

### Creating a promotion programmatically

```ruby
promo = Promotable::Promotion.create!(
  name: "Summer Sale",
  description: "20% off orders over $50",
  active: true,
  starts_at: Date.new(2026, 6, 1),
  expires_at: Date.new(2026, 8, 31),
  usage_limit: 1000,
  per_user_limit: 1,
  priority: 0,
  stackable: false
)

# Add a rule: minimum $50 order
promo.rules.create!(
  type: "Promotable::Rules::MinimumAmountRule",
  preferences: { minimum_amount: 50 }
)

# Add an action: 20% discount
promo.actions.create!(
  type: "Promotable::Actions::PercentageDiscount",
  preferences: { percentage: 20 }
)

# Create a coupon code
promo.codes.create!(code: "SUMMER20", usage_limit: 500)
```

### Querying promotions

```ruby
Promotable::Promotion.active        # currently enabled
Promotable::Promotion.current       # within date range
Promotable::Promotion.available     # active + current, ordered by priority
Promotable::Promotion.stackable     # can combine with others

# Check from the user side
user.used_promotion?(promo)         # => true/false
user.promotion_usage_count(promo)   # => 2
user.available_promotions           # promotions the user can still use
```

## Built-in Rules

Rules are eligibility conditions -- **all** rules on a promotion must pass for it to apply.

| Rule | Preferences | Description |
|---|---|---|
| `Promotable::Rules::MinimumAmountRule` | `{ minimum_amount: 50.0 }` | Promotable's `#promotable_amount` must meet the threshold. |
| `Promotable::Rules::ItemQuantityRule` | `{ minimum_quantity: 3 }` | Promotable's `#promotable_items` count must meet the threshold. |
| `Promotable::Rules::FirstPurchaseRule` | *(none)* | User must have zero prior code usages. Requires `user` in context. |
| `Promotable::Rules::UserEligibilityRule` | `{ eligible_group: "vip" }` | User's `#promotion_group` must match. Requires `user` in context. |

## Built-in Actions

Actions define what discount to apply when a promotion is eligible.

| Action | Preferences | Description |
|---|---|---|
| `Promotable::Actions::PercentageDiscount` | `{ percentage: 10 }` | Applies X% off the `#promotable_amount`. |
| `Promotable::Actions::FixedAmountDiscount` | `{ amount: 15.0 }` | Applies a flat discount, capped at the promotable amount. |
| `Promotable::Actions::FreeShippingDiscount` | *(none)* | Negates `#promotable_shipping_cost`. |

## Creating Custom Rules

### Using the generator

```bash
rails generate promotable:rule LoyaltyTier required_tier:integer
```

This creates `app/models/loyalty_tier_rule.rb` and a corresponding test file.

### Manual creation

Subclass `Promotable::Rules::Base` and implement the private `#evaluate` method:

```ruby
class LoyaltyTierRule < Promotable::Rules::Base
  store_accessor :preferences, :required_tier

  def self.preference_fields
    [{ name: :required_tier, type: :integer, default: 1 }]
  end

  private

  # Return true if the promotable meets this rule's criteria.
  # `context` contains :user and other data passed through the system.
  def evaluate(promotable, context = {})
    user = context[:user]
    return false unless user&.respond_to?(:loyalty_tier)

    user.loyalty_tier >= required_tier.to_i
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

You can also override `#pre_check` to add fast-fail guards before `#evaluate` runs:

```ruby
private

def pre_check(_promotable, context)
  context[:user].present?
end
```

## Creating Custom Actions

### Using the generator

```bash
rails generate promotable:action BonusPoints points:integer
```

### Manual creation

Subclass `Promotable::Actions::Base` and implement `#compute_amount` and `#apply`:

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

## Configuration

The initializer at `config/initializers/promotable.rb` supports these options:

```ruby
Promotable.configure do |config|
  # Maximum promotions that can be applied to a single promotable (default: 5)
  config.max_promotions_per_promotable = 5

  # Whether multiple promotions can stack on the same promotable (default: true)
  config.allow_stacking = true

  # Whether promotion codes are case-sensitive (default: false)
  # When false, "save20" and "SAVE20" are treated as the same code
  config.code_case_sensitive = false

  # Register custom rules
  config.rule_registry.register(:loyalty_tier, LoyaltyTierRule)

  # Register custom actions
  config.action_registry.register(:bogo, BuyOneGetOneAction)
end
```

### Promotable interface contract

Models using `acts_as_promotable` **must** implement:

| Method | Return type | Required by |
|---|---|---|
| `#promotable_amount` | `BigDecimal` | All rules and actions |
| `#promotable_items` | Array-like | `ItemQuantityRule` |
| `#promotable_shipping_cost` | `BigDecimal` | `FreeShippingDiscount` |

Models using `acts_as_promoter` optionally implement:

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
| `Promotable::PromotableInterfaceError` | Model does not implement a required interface method. |

```ruby
begin
  order.apply_promotion_code("BADCODE", user: user)
rescue Promotable::Error => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

## Database Schema

Promotable creates six tables, all prefixed with `promotable_`:

- `promotable_promotions` -- core promotion records
- `promotable_rules` -- STI-based eligibility rules
- `promotable_actions` -- STI-based discount actions
- `promotable_promotion_codes` -- redeemable coupon codes
- `promotable_code_usages` -- polymorphic usage tracking
- `promotable_adjustments` -- polymorphic discount records

All preference/metadata columns use `json` for cross-database compatibility (PostgreSQL, MySQL, SQLite).

## Testing

Run the gem's test suite:

```bash
cd promotable
bundle exec rake test
```

The gem ships with 90 tests covering models, services, registry, configuration, and integration through a dummy Rails app.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
