# Promotable

An extensible promotion and coupon engine for Ruby on Rails 8+. Promotable provides a type-agnostic, pluggable promotion system that you can attach to **any** model -- orders, carts, subscriptions, bookings -- without modifying the gem itself.

**Key design goals:** extensibility through STI-based rules/actions, a thread-safe registry for custom types, first-class multitenancy via [acts_as_tenant](https://github.com/ErwinM/acts_as_tenant), a pluggable host contract with configurable enforcement, and clean host-app integration via `acts_as_promotable` / `acts_as_promoter` concerns.

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
  - [Running Under Docker](#running-under-docker)
  - [Testing in Your Host App](#testing-in-your-host-app)
- [Architecture](#architecture)
- [Contributing](#contributing)
  - [Getting Started](#getting-started)
  - [Development Workflow](#development-workflow)
  - [Code Guidelines](#code-guidelines)
  - [Adding a New Built-in Rule](#adding-a-new-built-in-rule)
  - [Adding a New Built-in Action](#adding-a-new-built-in-action)
  - [Adding a Configuration Option](#adding-a-configuration-option)
  - [Documentation & PR Checklist](#documentation--pr-checklist)
  - [Reporting Issues](#reporting-issues)
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

Any model that can _receive_ promotions (e.g. Order, Cart, Subscription) calls `acts_as_promotable` and implements the `#promotable_amount` method:

```ruby
class Order < ApplicationRecord
  acts_as_promotable

  # REQUIRED -- return the base amount before discounts as a BigDecimal.
  def promotable_amount
    BigDecimal(total_price.to_s)
  end
end
```

This gives your model:

| Method                              | Description                                                          |
| ----------------------------------- | -------------------------------------------------------------------- |
| `apply_promotion_code(code, user:)` | Redeem a coupon code on this record.                                 |
| `apply_best_promotions(user:)`      | Auto-apply all eligible promotions.                                  |
| `remove_all_promotions`             | Remove every adjustment from this record.                            |
| `recalculate_promotions(user:)`     | Remove then re-apply eligible promotions.                            |
| `promotion_total_discount`          | Sum of all eligible adjustment amounts (negative = discount).        |
| `active_promotions`                 | Array of distinct `Promotable::Promotion` records currently applied. |
| `promotable_adjustments`            | ActiveRecord association of `Promotable::Adjustment` records.        |
| `promotable_code_usages`            | ActiveRecord association of `Promotable::CodeUsage` records.         |

### 2. Mark your user model

Any model that _redeems_ promotions calls `acts_as_promoter`:

```ruby
class User < ApplicationRecord
  acts_as_promoter
end
```

This gives your model:

| Method                             | Description                                                  |
| ---------------------------------- | ------------------------------------------------------------ |
| `promotion_usage_count(promotion)` | How many times this user has used a given promotion.         |
| `used_promotion?(promotion)`       | Whether this user has used the promotion at all.             |
| `available_promotions`             | All active promotions this user is still eligible for.       |
| `promotion_code_usages`            | ActiveRecord association of `Promotable::CodeUsage` records. |

### 3. Configure (optional)

Edit `config/initializers/promotable.rb` to customize behavior and register custom types. See the [Configuration](#configuration) section for all options.

### 4. Multitenancy

Promotable ships with first-class multitenancy via [acts_as_tenant](https://github.com/ErwinM/acts_as_tenant). Every promotion, code, usage, and adjustment is scoped by `client_id`, and the tenant model is configurable:

```bash
rails generate promotable:install --tenant-model=Client --require-tenant
```

At runtime, wrap requests in `ActsAsTenant.with_tenant(client) { ... }` (or use `set_current_tenant_through_filter`). Promotions with `client_id: nil` behave as **global** promotions visible to every tenant — useful for platform-wide campaigns. Setting `require_tenant = true` disables the global fallback and refuses any Promotable query without an active tenant.

Codes are unique **per tenant**, so `SUMMER25` may exist for many clients simultaneously without collision.

## Core Concepts

| Concept           | Model                       | Description                                                                                        |
| ----------------- | --------------------------- | -------------------------------------------------------------------------------------------------- |
| **Promotion**     | `Promotable::Promotion`     | The central entity: a named promotion with date range, usage limits, priority, and stacking rules. |
| **Rule**          | `Promotable::Rules::Base`   | An eligibility condition (STI). All rules on a promotion must pass for it to apply.                |
| **Action**        | `Promotable::Actions::Base` | A discount behavior (STI). Each action creates an `Adjustment` when applied.                       |
| **PromotionCode** | `Promotable::PromotionCode` | A redeemable coupon code string linked to a promotion, with its own usage limit.                   |
| **Adjustment**    | `Promotable::Adjustment`    | A polymorphic record tracking an applied discount on any promotable.                               |
| **CodeUsage**     | `Promotable::CodeUsage`     | Tracks who used which code on which promotable, enabling per-user limits.                          |

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

This finds all eligible promotions, sorts them by priority, and applies them while respecting stacking rules.

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

| Field            | Type       | Default    | Description                                            |
| ---------------- | ---------- | ---------- | ------------------------------------------------------ |
| `name`           | `string`   | _required_ | Display name of the promotion.                         |
| `description`    | `text`     | `nil`      | Human-readable description.                            |
| `promotion_type` | `string`   | `nil`      | Free-form label for categorization.                    |
| `starts_at`      | `datetime` | `nil`      | When the promotion becomes valid. `nil` = immediately. |
| `expires_at`     | `datetime` | `nil`      | When the promotion expires. `nil` = never.             |
| `usage_limit`    | `integer`  | `nil`      | Max total redemptions. `nil` = unlimited.              |
| `per_user_limit` | `integer`  | `nil`      | Max redemptions per user. `nil` = unlimited.           |
| `usage_count`    | `integer`  | `0`        | Current total redemptions (auto-incremented).          |
| `active`         | `boolean`  | `false`    | Master on/off switch.                                  |
| `priority`       | `integer`  | `0`        | Lower = applied first.                                 |
| `stackable`      | `boolean`  | `true`     | Whether this can combine with other promotions.        |
| `metadata`       | `json`     | `{}`       | Arbitrary key-value data for your application.         |

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

# Copy the gem's migrations into the host app's db/migrate.
# (Also invoked automatically by `rails generate promotable:install`.)
rails promotable:install:migrations
```

### Admin panel

The dummy app under `spec/dummy` ships with a full [Avo](https://avohq.io) admin dashboard covering every Promotable model (`Promotable::Promotion`, `PromotionCode`, `Rule`, `Action`, `Adjustment`, `CodeUsage`) plus the dummy `Client`, `Order`, `LineItem`, and `User` records. Use it as a reference for wiring your own admin resources; the resource files live in [spec/dummy/app/avo/resources](spec/dummy/app/avo/resources).

`config/routes.rb` in the gem mounts `mount_avo` under the engine, so any host that mounts the engine also gets these panels for free once Avo is configured in the host app.

## Built-in Rules

Rules are eligibility conditions. **All** rules on a promotion must pass for it to apply.

Order-scoped rules (host contract lives on `acts_as_promotable`):

| Rule                  | Preferences                                           | Host method(s)                                           |
| --------------------- | ----------------------------------------------------- | -------------------------------------------------------- |
| `MinimumAmountRule`   | `minimum_amount`                                      | `promotable_amount`                                      |
| `MaximumAmountRule`   | `maximum_amount`                                      | `promotable_amount`                                      |
| `MinimumQuantityRule` | `minimum_quantity`                                    | `promotable_item_count` or `promotable_items[].quantity` |
| `CountryRule`         | `countries: [...]` (ISO)                              | `promotable_country`                                     |
| `StoreRule`           | `store_ids: [...]`                                    | `promotable_store_id`                                    |
| `SourceRule`          | `sources: [...]` (`web`, `pos`, `app`, ...)           | `promotable_source`                                      |
| `PaymentMethodRule`   | `methods: [...]`                                      | `promotable_payment_method`                              |
| `ProductVariantRule`  | `variant_ids: [...]`, `mode: include\|exclude`        | `promotable_items[].variant_id`                          |
| `CategoryRule`        | `category_ids: [...]`, `mode: include\|exclude`       | `promotable_items[].category_id[s]`                      |
| `TimeWindowRule`      | `days_of_week`, `start_hour`, `end_hour`, `time_zone` | none (uses server clock)                                 |

User-scoped rules (require `user:` in context, host contract on `acts_as_promoter`):

| Rule                | Preferences                                       | Host method(s)                                       |
| ------------------- | ------------------------------------------------- | ---------------------------------------------------- |
| `FirstPurchaseRule` | —                                                 | `promotable_order_count`                             |
| `NewUserRule`       | `within_days` (default 30)                        | `created_at`                                         |
| `UserActivityRule`  | `min_orders`, `max_orders`, `max_days_since_last` | `promotable_order_count`, `promotable_last_order_at` |
| `AllowedUsersRule`  | `user_ids: [...]` and/or `user_group`             | `id`, `promotion_group`                              |
| `FrequencyRule`     | `max_uses`, `period: day\|week\|month\|ever`      | `id`                                                 |
| `BirthdayRule`      | `window_days` (default 0)                         | `birthday`                                           |

All example preferences:

```ruby
promo.rules.create!(
  type: "Promotable::Rules::MinimumAmountRule",
  preferences: { minimum_amount: 50.0 }
)

promo.rules.create!(
  type: "Promotable::Rules::TimeWindowRule",
  preferences: { days_of_week: [1, 2, 3, 4, 5], start_hour: 9, end_hour: 17, time_zone: "UTC" }
)

promo.rules.create!(
  type: "Promotable::Rules::FrequencyRule",
  preferences: { max_uses: 1, period: "day" }
)
```

Rules that require user context declare it via `requires_context`, so calling
`rule.eligible?(order)` without `user:` raises `Promotable::MissingContextError`.

## Built-in Actions

Actions define the discount to apply when a promotion is eligible.

| Action                     | Preferences                                                    | Notes                                                   |
| -------------------------- | -------------------------------------------------------------- | ------------------------------------------------------- |
| `PercentageDiscount`       | `percentage`                                                   | Applies X% off `promotable_amount`.                     |
| `FixedAmountDiscount`      | `amount`                                                       | Flat currency amount off; capped at order total.        |
| `CappedPercentageDiscount` | `percentage`, `max_amount`                                     | Percentage discount with an absolute ceiling.           |
| `FreeShippingAction`       | —                                                              | Reads `promotable_shipping_cost`; discounts it in full. |
| `TieredDiscountAction`     | `tiers: [{ min_amount:, discount:, type: fixed\|percentage }]` | Picks the highest matching tier.                        |

Examples:

```ruby
promo.actions.create!(
  type: "Promotable::Actions::PercentageDiscount",
  preferences: { percentage: 15 }
)

promo.actions.create!(
  type: "Promotable::Actions::TieredDiscountAction",
  preferences: {
    tiers: [
      { min_amount: 50,  discount: 5,  type: "fixed" },
      { min_amount: 150, discount: 20, type: "percentage" }
    ]
  }
)
```

## Creating Custom Rules

### Using the generator

```bash
rails generate promotable:rule LoyaltyTier required_tier:integer
```

This creates `app/models/loyalty_tier_rule.rb` and `spec/models/loyalty_tier_rule_spec.rb`.

### Manual creation

Subclass `Promotable::Rules::Base` and implement the private `#evaluate` method. Declare any context keys the rule reads via `requires_context`, and optionally override `#pre_check` for fast-fail guards beyond the built-in context check.

```ruby
class LoyaltyTierRule < Promotable::Rules::Base
  requires_context :user

  store_accessor :preferences, :required_tier

  validates :required_tier, presence: true, on: :rule_validation

  def self.preference_fields
    [{ name: :required_tier, type: :integer, default: 1 }]
  end

  private

  def pre_check(_promotable, context)
    context[:user].respond_to?(:loyalty_tier)
  end

  def evaluate(_promotable, context = {})
    context[:user].loyalty_tier >= required_tier.to_i
  end
end
```

Reach into optional host methods via `Promotable::ContractResolver` so the configured `on_missing_contract_method` policy (`:skip`, `:log`, `:raise`) is honored:

```ruby
tier = Promotable::ContractResolver.call(context[:user], :loyalty_tier)
return false if tier.nil?
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

| Method                            | Visibility     | Must implement? | Description                                                                                        |
| --------------------------------- | -------------- | --------------- | -------------------------------------------------------------------------------------------------- |
| `#eligible?(promotable, context)` | public         | No (inherited)  | Entry point. Calls `pre_check` then `evaluate`.                                                    |
| `#pre_check(promotable, context)` | private        | Optional        | Fast-fail guard. Return `false` to skip `evaluate`. Defaults to enforcing `requires_context` keys. |
| `#evaluate(promotable, context)`  | private        | **Yes**         | Return `true` if the promotable meets this rule's criteria.                                        |
| `.requires_context(*keys)`        | public (class) | Optional        | Declare context keys the rule reads. Missing keys raise `Promotable::MissingContextError`.         |
| `.preference_fields`              | public (class) | Optional        | Returns an array of hashes describing configurable preferences (used by admin UI + generators).    |
| `.display_name`                   | public (class) | No (inherited)  | Human-readable class name, defaults to the demodulized underscored form.                           |

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

| Method                                           | Visibility          | Must implement? | Description                                                                                  |
| ------------------------------------------------ | ------------------- | --------------- | -------------------------------------------------------------------------------------------- |
| `#apply(promotable, context)`                    | public              | **Yes**         | Execute the discount. Call `create_adjustment` to persist.                                   |
| `#compute_amount(promotable, context)`           | public              | **Yes**         | Return the discount as a negative `BigDecimal` (or positive for surcharges).                 |
| `#undo(promotable, context)`                     | public              | No (inherited)  | Removes adjustments for the promotable. Override for custom cleanup / external side effects. |
| `#adjustment_label(promotable, context)`         | public              | Optional        | Human-readable label attached to the created `Adjustment`. Defaults to `.display_name`.      |
| `.preference_fields`                             | public (class)      | Optional        | Array of hashes describing configurable preferences.                                         |
| `.display_name`                                  | public (class)      | No (inherited)  | Human-readable class name, defaults to the demodulized underscored form.                     |
| `#create_adjustment(promotable, amount, label:)` | private (inherited) | N/A             | Helper to create an `Adjustment` record.                                                     |
| `#remove_adjustments(promotable)`                | private (inherited) | N/A             | Helper to destroy this action's adjustments for a promotable.                                |

## Configuration

The initializer at `config/initializers/promotable.rb` supports these options:

```ruby
Promotable.configure do |config|
  # Whether multiple promotions can stack on the same promotable.
  # When false, only the highest-priority promotion is applied.
  # Default: false
  config.allow_stacking = false

  # Whether promotion codes are case-sensitive.
  # When true, "save20" and "SAVE20" are treated as different codes.
  # Default: true
  config.code_case_sensitive = true

  # Host model that owns promotions. Backed by acts_as_tenant on client_id.
  # Default: "Client"
  config.tenant_model_name = "Client"

  # When true, all Promotable queries require an ActsAsTenant.current_tenant
  # and refuse to fall back to global (client_id: nil) records.
  # Default: false
  config.require_tenant = false

  # Resolve the current tenant globally when acts_as_tenant is not set.
  # Default: nil
  config.current_tenant_resolver = -> { Current.client }

  # How to react when a host object is missing an optional contract method
  # (e.g. Order#promotable_country used by CountryRule).
  # One of :skip, :log, :raise. Default: :log
  config.on_missing_contract_method = :log

  # Logger used for missing-contract warnings. Falls back to Rails.logger.
  # config.logger = Rails.logger

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

| Method               | Return type  | Required by                                                          |
| -------------------- | ------------ | -------------------------------------------------------------------- |
| `#promotable_amount` | `BigDecimal` | All rules and actions. Raises `PromotableInterfaceError` if missing. |

Models using `acts_as_promotable` **may** implement (unlocks the matching built-in rules and actions — see the tables in [Built-in Rules](#built-in-rules)):

| Method                       | Return type  | Consumers                                   |
| ---------------------------- | ------------ | ------------------------------------------- |
| `#promotable_items`          | Array-like   | `MinimumQuantityRule`, custom rules/actions |
| `#promotable_item_count`     | `Integer`    | `MinimumQuantityRule`                       |
| `#promotable_shipping_cost`  | `BigDecimal` | `FreeShippingAction`                        |
| `#promotable_country`        | `String`     | `CountryRule`                               |
| `#promotable_store_id`       | `Integer`    | `StoreRule`                                 |
| `#promotable_source`         | `String`     | `SourceRule`                                |
| `#promotable_payment_method` | `String`     | `PaymentMethodRule`                         |

Models using `acts_as_promoter` **may** implement:

| Method                      | Return type         | Consumers                               |
| --------------------------- | ------------------- | --------------------------------------- |
| `#promotable_order_count`   | `Integer`           | `FirstPurchaseRule`, `UserActivityRule` |
| `#promotable_last_order_at` | `Time` / `DateTime` | `UserActivityRule`                      |
| `#birthday`                 | `Date`              | `BirthdayRule`                          |
| `#promotion_group`          | `String`            | `AllowedUsersRule`                      |

When an optional method is missing, `Promotable::ContractResolver` returns `nil` and rules that depend on it evaluate to ineligible. Set `config.on_missing_contract_method = :raise` in tests to catch integration gaps early.

## Error Handling

All errors inherit from `Promotable::Error`, so you can rescue broadly or specifically:

| Error                                  | Raised when                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `Promotable::InvalidCodeError`         | Promotion code string not found in the database (in the current tenant scope).                    |
| `Promotable::IneligibleError`          | Promotion exists but fails eligibility checks.                                                    |
| `Promotable::PromotionInactiveError`   | Promotion's `active` flag is `false`.                                                             |
| `Promotable::PromotionExpiredError`    | Promotion is outside its `starts_at..expires_at` range.                                           |
| `Promotable::UsageLimitExceededError`  | Code, promotion, or per-user usage limit reached.                                                 |
| `Promotable::StackingNotAllowedError`  | Stacking is disabled and a promotion is already applied.                                          |
| `Promotable::PromotableInterfaceError` | Model does not implement a required interface method (e.g. `#promotable_amount`).                 |
| `Promotable::MissingContextError`      | A rule declared `requires_context :key` but the caller did not pass it.                           |
| `Promotable::ContractError`            | `config.on_missing_contract_method = :raise` and the host is missing an optional contract method. |

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

| Table                        | Purpose                                                                              |
| ---------------------------- | ------------------------------------------------------------------------------------ |
| `promotable_promotions`      | Core promotion records with dates, limits, priority, stacking, `client_id`.          |
| `promotable_rules`           | STI-based eligibility rules. `type` column resolves the subclass.                    |
| `promotable_actions`         | STI-based discount actions. `type` column resolves the subclass.                     |
| `promotable_promotion_codes` | Redeemable coupon codes. Unique on `(client_id, code)` so tenants can reuse strings. |
| `promotable_code_usages`     | Polymorphic join tracking which user used which code on which promotable.            |
| `promotable_adjustments`     | Polymorphic discount records attached to any promotable model.                       |

All `preferences` and `metadata` columns use the `json` type for cross-database compatibility (PostgreSQL, MySQL, SQLite).

Indexes are added on `active`, `priority`, `starts_at + expires_at`, `type` (rules/actions), `(client_id, code)` (unique on codes), `client_id` (all tenant-scoped tables), and `eligible` (adjustments).

The `client_id` column is denormalized onto `promotable_promotion_codes`, `promotable_code_usages`, and `promotable_adjustments` so `acts_as_tenant` can filter each table directly without joining back to the promotion. Migrations manage this automatically — see `db/migrate/20260722000002_*.rb` and `db/migrate/20260726000003_*.rb`.

## Generators

### Install

```bash
rails generate promotable:install [--tenant-model=Client] [--require-tenant]
```

Copies the migration into your app (via the `promotable:install:migrations` rake task) and creates `config/initializers/promotable.rb`. Options:

| Option             | Default  | Effect                                                                     |
| ------------------ | -------- | -------------------------------------------------------------------------- |
| `--tenant-model`   | `Client` | Sets `config.tenant_model_name` in the generated initializer.              |
| `--require-tenant` | `false`  | Sets `config.require_tenant = true`, disabling the global-record fallback. |

### Custom Rule

```bash
rails generate promotable:rule RuleName field_name:type field_name:type [--requires-context=user client]
```

Creates a rule subclass with `store_accessor` for each field, an optional `requires_context` declaration for context keys the rule reads, and a matching test file at `spec/models/rule_name_rule_spec.rb`. After generating, register it in `config/initializers/promotable.rb`.

### Custom Action

```bash
rails generate promotable:action ActionName field_name:type field_name:type
```

Creates an action subclass with `store_accessor` for each field and a matching test file at `spec/models/action_name_action_spec.rb`.

## Testing

### Running the gem test suite

```bash
cd promotable
bundle install
bundle exec rspec
```

The gem currently ships with **154 examples across 33 spec files**, covering:

- **Model tests** -- `Promotion`, `PromotionCode`, `Adjustment`, every `Rules::*` subclass, every `Actions::*` subclass.
- **Service tests** -- `Evaluator`, `Applicator`, `CodeRedeemer`.
- **Registry tests** -- registration, resolution, validation, thread safety, reload-safety.
- **Configuration tests** -- defaults, DSL, reset, `ContractResolver` modes.
- **Concern tests** -- `ActsAsPromotable` and `ActsAsPromoter` including the interface contract.
- **Multitenancy tests** -- cross-tenant leak-proof invariants for every read and write path.
- **Host-app integration** -- full flows using the dummy Rails app under `spec/dummy` (with `Client`, `Order`, `LineItem`, `User`).

The default `rake` task runs `bundle exec rspec`.

### Running under Docker

The dummy app is fully dockerized so you can run the gem without a local Ruby toolchain:

```bash
docker compose up                                # boots the dummy app on http://localhost:4000
docker compose run --rm app bundle exec rspec    # runs the whole spec suite
docker compose run --rm app bash                 # drops into a shell inside the container
```

`Makefile` shortcuts (`make build`, `make up`, `make down`, `make bash`, `make console`, `make fix-lint`) wrap the common commands.

### Testing in your host app

When writing tests that involve promotions in your application:

```ruby
RSpec.describe "Order promotions" do
  it "applies coupon codes and creates adjustments" do
    promo = Promotable::Promotion.create!(
      name: "Test Promo",
      active: true,
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now
    )
    promo.actions.create!(
      type: "Promotable::Actions::PercentageDiscount",
      preferences: { percentage: 10 }
    )
    promo.codes.create!(code: "TEST10")

    order = Order.create!(total_price: 100)
    user = User.create!(name: "Tester")

    order.apply_promotion_code("TEST10", user: user)

    expect(order.promotion_total_discount).to eq(BigDecimal("-10"))
    expect(order.promotable_adjustments.count).to eq(1)
  end

  it "raises InvalidCodeError for unknown codes" do
    order = Order.create!(total_price: 100)
    user = User.create!(name: "Tester")

    expect { order.apply_promotion_code("NOPE", user: user) }
      .to raise_error(Promotable::InvalidCodeError)
  end
end
```

Promotable's own test suite uses RSpec.

## Architecture

For a deep dive into the internal design -- design patterns (Strategy, Template Method, Registry, Contract Resolver), multitenancy model, data model ER diagrams, service layer sequence diagrams, and extension points -- see [ARCHITECTURE.md](ARCHITECTURE.md).

Migrating an existing bespoke coupon system? [HIVE_MIGRATION.md](HIVE_MIGRATION.md) maps common legacy patterns onto the built-in rules and actions and doubles as a checklist for porting campaigns.

## Contributing

Promotable is designed to be extended -- most feature work lands as new rule or action classes, not as edits to the core. This section is the reference for that workflow.

### Getting started

1. Fork the repository and clone your fork.
2. Install dependencies:

   ```bash
   cd promotable
   bundle install
   ```

3. Set up the test database (the dummy app lives at `spec/dummy` and Rails loads migrations from **both** `db/migrate` and `spec/dummy/db/migrate`):

   ```bash
   cd spec/dummy
   RAILS_ENV=test bin/rails db:create db:migrate
   cd ../..
   ```

4. Run the test suite to confirm everything passes:

   ```bash
   bundle exec rspec
   ```

Prefer Docker? `docker compose run --rm app bundle exec rspec` runs the suite inside the container.

### Development workflow

- The gem uses a **dummy Rails app** at `spec/dummy/` for integration testing. It contains `Client`, `Order`, `LineItem`, and `User` models that use `acts_as_promotable` and `acts_as_promoter`. Anything you need to exercise a new rule or action end-to-end goes in there.
- Source code lives in `app/models/promotable/` (persisted models -- rules, actions, promotion, code, usage, adjustment) and `lib/promotable/` (services, concerns, configuration, registry, contract resolver, errors, engine).
- Specs mirror the source structure under `spec/`. Every new class needs a matching `*_spec.rb`.
- Both `db/migrate` and `spec/dummy/db/migrate` are on the migration path; keep migration timestamps unique across the two folders.
- New migrations should be **forward-only additions**. Do not edit historical migrations -- add a new one instead.

Create a feature branch off `main` before making changes:

```bash
git checkout -b feature/my-improvement
```

Then commit as you go and open a pull request against `main` when ready.

### Code guidelines

- **No monkey-patching** of core Ruby or Rails classes.
- **Use STI** for new rule or action types -- do not add conditional logic to the base classes.
- **Store runtime configuration** in the `preferences` JSON column via `store_accessor`, not as new database columns. The gem never needs a new table to model a new campaign shape.
- **Keep services stateless** -- instantiate them per request, do not cache state between calls, do not stash things in class-level state.
- **Use `BigDecimal`** for all monetary calculations, never `Float`.
- **Read host contract methods through `Promotable::ContractResolver`** (not `respond_to?` + direct send). This ensures the configured `on_missing_contract_method` policy is honored uniformly.
- **Return meaningful errors** -- raise a specific `Promotable::Error` subclass with a descriptive message. Add a new error subclass under `lib/promotable/errors.rb` if none of the existing ones fit.
- **Respect the tenant scope** -- new services and helpers that read/write tenant-scoped tables must run inside `ActsAsTenant.with_tenant(...)` or explicitly use `ActsAsTenant.without_tenant` with a comment explaining why.
- **`preferences` validations use custom contexts** (`on: :rule_validation` for rules, `on: :action_validation` for actions) so that host apps can persist partial records during admin flows. Trigger them explicitly with `record.valid?(:rule_validation)` in tests.
- All public methods should be covered by tests -- aim for the same coverage bar as the surrounding code.
- Run `bin/rubocop -A` (or `make fix-lint`) before pushing; the project uses `rubocop-rails-omakase`.

### Adding a new built-in rule

1. Create `app/models/promotable/rules/my_rule.rb` inheriting from `Rules::Base`.
2. Implement `#evaluate` (required) and optionally `#pre_check` for fast-fail guards.
3. If the rule reads from `context[:user]`, `context[:client]`, or any other key, declare it up front:

   ```ruby
   requires_context :user
   ```

   The base class raises `Promotable::MissingContextError` if a call site forgets to pass a required key.

4. Add `self.preference_fields` describing configurable preferences (used by the Avo admin panel and generators).
5. Add `store_accessor :preferences, :field_name` for each preference.
6. If preferences must be present, gate the validation with `on: :rule_validation` so partial admin drafts do not fail.
7. Reach the host through `Promotable::ContractResolver.call(target, :method_name)` for any optional contract method.
8. Register it in `Configuration#register_defaults!` (or, for gem-external rules, in the host app's initializer via `config.rule_registry.register(:key, MyRule)`).
9. Add specs in `spec/models/promotable/rules/my_rule_spec.rb`.
10. Update the [Built-in Rules](#built-in-rules) table in this README and add a row to [HIVE_MIGRATION.md](HIVE_MIGRATION.md) if the new rule replaces a legacy pattern.

### Adding a new built-in action

1. Create `app/models/promotable/actions/my_action.rb` inheriting from `Actions::Base`.
2. Implement `#compute_amount` (returns a **negative** `BigDecimal` for discounts, positive for surcharges) and `#apply` (calls `create_adjustment(promotable, amount, label:)`).
3. Optionally override `#adjustment_label(promotable, context)` for a human-friendly label (e.g. `"15% off"`, `"Free shipping"`); the default falls back to the class display name.
4. `#undo` is inherited and removes this action's adjustments for the promotable -- override only if you have external side effects to reverse.
5. Add `self.preference_fields` and `store_accessor :preferences, :field_name` for each preference. Use `on: :action_validation` for presence checks on required preferences.
6. Register it in `Configuration#register_defaults!` (or in the host app's initializer for gem-external actions).
7. Add specs in `spec/models/promotable/actions/my_action_spec.rb`.
8. Update the [Built-in Actions](#built-in-actions) table.

### Adding a configuration option

1. Add the attribute to `Promotable::Configuration` with a sensible default in `#initialize`.
2. Comment the new option in the install generator template at `lib/generators/promotable/install/templates/initializer.rb`.
3. Read it through `Promotable.configuration&.<option>` in the calling code (never as a top-level constant).
4. Add a spec in `spec/configuration_spec.rb`.

### Documentation & PR checklist

Before opening a PR, confirm:

- [ ] `bundle exec rspec` passes and the new/changed code is covered.
- [ ] `bin/rubocop` reports no offenses (or `bin/rubocop -A` was run and the auto-fixes are intentional).
- [ ] The change is described in the PR body: user-facing behavior, migration path if any, and links to any issues.
- [ ] The README's [Built-in Rules](#built-in-rules) / [Built-in Actions](#built-in-actions) / [Configuration](#configuration) / [Error Handling](#error-handling) tables are updated when they apply.
- [ ] `ARCHITECTURE.md` is updated if you introduced a new design pattern, extension point, or data-model change.
- [ ] `HIVE_MIGRATION.md` gets a row when your change maps a legacy Hive coupon pattern onto a Promotable primitive.
- [ ] Any new migration lives in `db/migrate/` (and in `spec/dummy/db/migrate/` for the dummy app's schema), with a unique timestamp.
- [ ] No Ruby warnings in the test output.

### Reporting issues

- Use the GitHub issue tracker.
- Include your Ruby version, Rails version, database adapter, gem version (`Promotable::VERSION`), and the full error backtrace.
- Provide a minimal reproduction case -- ideally a failing spec against `spec/dummy` -- when possible.
- For security-sensitive reports, follow the process described in [SECURITY.md](SECURITY.md) instead of filing a public issue.

## Changelog

All notable changes are documented in [CHANGELOG.md](CHANGELOG.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
