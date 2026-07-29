# Promotable -- Architecture

This document describes the internal architecture, design patterns, data model, and extension points of the Promotable engine. It is written for two audiences: consumers who want a mental model of how the pieces fit together, and contributors who want to know where new code should land.

## System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Host Application                                                        │
│                                                                          │
│   Client (tenant root)                                                   │
│   Order (acts_as_promotable)   User (acts_as_promoter)                  │
│   config/initializers/promotable.rb                                      │
└────────┬──────────────────────────┬───────────────────────┬─────────────┘
         │ includes                 │ includes              │ configures
         ▼                          ▼                       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  Promotable Engine                                                       │
│                                                                          │
│  ┌── Host Integration ──────┐   ┌── Infrastructure ───────────────────┐ │
│  │  ActsAsPromotable        │   │  Registry       Configuration       │ │
│  │  ActsAsPromoter          │   │  Engine         Error hierarchy     │ │
│  │  ContractResolver        │   │  TenantScoped   (acts_as_tenant)    │ │
│  └──────────────────────────┘   └─────────────────────────────────────┘ │
│           │ delegates                    │ registers / scopes            │
│           ▼                              ▼                               │
│  ┌── Service Layer ─────────┐   ┌── Domain Models ────────────────────┐ │
│  │  Evaluator  ─────────────┼──▶│  Rules::Base (STI)                 │ │
│  │  Applicator ─────────────┼──▶│  Actions::Base (STI)               │ │
│  │  CodeRedeemer            │   │  Promotion    PromotionCode         │ │
│  └──────────────────────────┘   │  Adjustment   CodeUsage            │ │
│                                  └─────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

Every domain model is **tenant-scoped**: `Promotion`, `PromotionCode`, `CodeUsage`, and `Adjustment` all carry a `client_id` column and include `Promotable::TenantScoped`, which wires up `acts_as_tenant` with `has_global_records: true`. A `client_id: nil` row is visible to every tenant; a scoped row is only visible when `ActsAsTenant.current_tenant` matches.

## Design Patterns

### 1. Strategy Pattern (via Single Table Inheritance)

Rules and Actions each use STI with a shared `type` column. Every subclass implements a fixed contract, making them interchangeable at runtime without any conditional logic in the calling code.

```
Rules::Base
  + eligible?(promotable, context) : bool      # public  – entry point
  - pre_check(promotable, context) : bool      # private – fast-fail hook (default: true)
  - evaluate(promotable, context)  : bool      # private – abstract, must override
    │
    └── MinimumAmountRule      overrides: evaluate
```

```
Actions::Base
  + apply(promotable, context)          : Adjustment   # public  – applies discount, returns Adjustment
  + undo(promotable, context)                          # public  – removes adjustments
  + compute_amount(promotable, context) : BigDecimal   # public  – abstract, must override
  - create_adjustment(promotable, amount, label)       # private – persists Adjustment record
  - remove_adjustments(promotable)                     # private – deletes existing adjustments
    │
    └── PercentageDiscount      overrides: compute_amount, apply
```

**Why STI?** Each rule/action row lives in one table (`promotable_rules` or `promotable_actions`) with a `type` column that Rails resolves to the correct class. This means a `Promotion` can `has_many :rules` and iterate over them uniformly -- each one responds to `#eligible?` but with completely different logic inside.

### 2. Template Method

Base classes define a skeleton algorithm with hook methods. Subclasses override only the hooks they need.

**`Rules::Base#eligible?`** executes two steps in order:

```
eligible?(promotable, context)
  |
  +-- pre_check(promotable, context)   # fast-fail guard (hook, enforces requires_context)
  |     |
  |     +-- return false if fails
  |     +-- raise Promotable::MissingContextError if a required context key is absent
  |
  +-- evaluate(promotable, context)    # actual logic (abstract, subclasses MUST override)
```

- `pre_check` -- optional hook for fast-fail guards. The default implementation enforces `requires_context` keys and otherwise returns `true`.
- `evaluate` -- the real eligibility logic. Raises `NotImplementedError` if not overridden.
- `requires_context :key1, :key2, ...` -- class-level DSL that declares which context keys the rule reads. Missing keys raise `Promotable::MissingContextError` from `pre_check`, turning a "silently returns false" bug into a loud, actionable failure.

This keeps rule implementations small and focused while preserving a consistent execution flow.

### 3. Registry Pattern

A thread-safe registry (backed by `Concurrent::Map`) lets host apps register custom rule and action classes at boot time. The engine never needs to know about custom types -- they are discovered through the registry.

```
Promotable.configure do |config|
  config.rule_registry     -->  Registry<Rules::Base>
  config.action_registry   -->  Registry<Actions::Base>
end
```

Registry enforces that every registered class is a subclass of the expected base:

```ruby
registry.register(:loyalty, LoyaltyRule)  # OK if LoyaltyRule < Rules::Base
registry.register(:bad, String)           # raises ArgumentError
```

The registry stores the base-class **name** rather than the `Class` object so registrations survive Rails' development-mode code reloading. Zeitwerk replaces `Class` objects on every reload; a captured reference would go stale and every second request would raise "must be a subclass of…" errors. Comparing by name keeps ancestry checks reload-safe.

### 4. Contract Enforcement (Contract Resolver)

Rules and actions frequently need optional host methods -- `promotable_country`, `promotable_shipping_cost`, `birthday`, and so on. Instead of scattering `respond_to?` checks across the codebase, all optional method resolution goes through a single point:

```ruby
country = Promotable::ContractResolver.call(promotable, :promotable_country)
```

`ContractResolver` honors `Promotable.configuration.on_missing_contract_method`:

| Mode     | Behavior on missing method                                                                |
| -------- | ----------------------------------------------------------------------------------------- |
| `:skip`  | Return `nil` silently.                                                                    |
| `:log`   | Log a per-`(class, method)` warning once, then return `nil`. **Default.**                 |
| `:raise` | Raise `Promotable::ContractError`. Useful in test suites to catch integration gaps early. |

This is what makes the built-in rules composable: `CountryRule` and `PaymentMethodRule` can coexist with hosts that only implement one of them, without either raising or silently misbehaving.

### 5. Tenant Isolation (acts_as_tenant + TenantScoped)

`Promotable::TenantScoped` is included by every tenant-scoped model. It calls `acts_as_tenant :client` with:

- `class_name:` derived from `Promotable.configuration.tenant_model_name` (default `"Client"`), so hosts can point at any tenant model (`Account`, `Organization`, ...).
- `optional: true` and `has_global_records: true`, so a `client_id: nil` row means "visible to every tenant".

The engine's `promotable.acts_as_tenant` initializer mirrors `Promotable.configuration.require_tenant` into `ActsAsTenant.configuration.require_tenant`, so setting it to `true` in the host initializer makes every Promotable query raise `NoTenantSet` outside a `with_tenant` block. Services (`Evaluator`, `Applicator`, `CodeRedeemer`) always wrap their reads in `ActsAsTenant.with_tenant(client) do ... end` -- either the explicit `client:` argument, the configured `current_tenant_resolver`, or the promotable's own `#client` -- so tenant boundaries are enforced at both the query layer and the application layer.

## Data Model

### Entity-Relationship Diagram

```
promotable_promotions
  id            bigint  PK
  name          string
  description   text
  promotion_type string
  starts_at     datetime
  expires_at    datetime
  usage_limit   integer
  per_user_limit integer
  usage_count   integer
  active        boolean
  priority      integer
  stackable     boolean
  metadata      json
  client_id     bigint  FK → tenant table   (nil = global)
  │
  ├──< promotable_rules
  │      id            bigint  PK
  │      promotion_id  bigint  FK → promotable_promotions
  │      type          string  (STI discriminator)
  │      preferences   json
  │
  ├──< promotable_actions
  │      id            bigint  PK
  │      promotion_id  bigint  FK → promotable_promotions
  │      type          string  (STI discriminator)
  │      preferences   json
  │      │
  │      └──< promotable_adjustments
  │             id                  bigint   PK
  │             promotion_id        bigint   FK → promotable_promotions
  │             promotion_action_id bigint   FK → promotable_actions
  │             adjustable_type     string   (polymorphic)
  │             adjustable_id       bigint   (polymorphic)
  │             amount              decimal  (precision 15, scale 4)
  │             label               string
  │             eligible            boolean
  │             metadata            json
  │             client_id           bigint   FK → tenant table (denormalized)
  │
  └──< promotable_promotion_codes
         id            bigint  PK
         promotion_id  bigint  FK → promotable_promotions
         code          string
         usage_limit   integer
         usage_count   integer
         client_id     bigint  FK → tenant table (denormalized)
         UNIQUE (client_id, code)
         │
         └──< promotable_code_usages
                id               bigint   PK
                promotion_code_id bigint  FK → promotable_promotion_codes
                user_type        string   (polymorphic)
                user_id          bigint   (polymorphic)
                promotable_type  string   (polymorphic)
                promotable_id    bigint   (polymorphic)
                client_id        bigint   FK → tenant table (denormalized)
```

### Key design decisions

| Decision                                | Rationale                                                                                                                                |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `json` columns for preferences/metadata | Portable across PostgreSQL, MySQL, and SQLite. Accessed via `store_accessor`.                                                            |
| Polymorphic `adjustable` on adjustments | Any model can receive discounts -- orders, carts, subscriptions, etc.                                                                    |
| Polymorphic `user` on code_usages       | Any authentication model works (User, Admin, Account).                                                                                   |
| `type` column on rules and actions      | STI discriminator -- Rails auto-resolves to the correct subclass.                                                                        |
| `stackable` + `priority` on promotions  | Controls whether promotions combine and in what order they apply.                                                                        |
| Separate `PromotionCode` model          | A single promotion can have many codes (batch-generated coupon campaigns).                                                               |
| `usage_count` as counter (not computed) | Avoids expensive COUNT queries on every eligibility check. Incremented transactionally.                                                  |
| `client_id` denormalized onto children  | Codes, usages, and adjustments carry their own `client_id` so `acts_as_tenant` filters each table without joining back to the promotion. |
| `UNIQUE (client_id, code)`              | Different tenants can safely reuse coupon strings (`SUMMER25` per client).                                                               |
| `after_save` propagation on `Promotion` | Reassigning a promotion's `client_id` cascades to codes/usages/adjustments so tenant scope stays consistent.                             |

## Service Layer

Three service objects orchestrate the promotion lifecycle. They are stateless and instantiated per-request.

### Request Flow: Code Redemption

```
Host App            CodeRedeemer        PromotionCode       Promotion           Applicator          Actions             Adjustment
    │                    │                    │                   │                   │                   │                   │
    │─ redeem("SAVE20") ▶│                    │                   │                   │                   │                   │
    │                    │─ find_code!("SAVE20") ──────────────▶ │                   │                   │                   │
    │                    │◀─ promotion_code ───────────────────── │                   │                   │                   │
    │                    │─ validate_promotion!(promotion) ──────▶│                   │                   │                   │
    │                    │─ validate_code!(promotion_code) ──▶   │                   │                   │                   │
    │                    │─ within_per_user_limit?(user) ────────▶│                   │                   │                   │
    │                    │                    │                   │                   │                   │                   │
    │                    │   ╔══════════════════════ Transaction ═══════════════════════════════════════════════════════════╗  │
    │                    │   ║                                    │                   │                   │                   ║  │
    │                    │── ║─ apply_single(promotion) ──────────────────────────▶  │                   │                   ║  │
    │                    │   ║                                    │◀─ eligible?(promotable, context) ─── │                   ║  │
    │                    │   ║                                    │  within_date_range? + usage_limit?   │                   ║  │
    │                    │   ║                                    │  rules.all?{ rule.eligible? }        │                   ║  │
    │                    │   ║                                    │──────────────────▶│                   │                   ║  │
    │                    │   ║                                    │                   │─ apply(promotable, context) ─────────║▶ │
    │                    │   ║                                    │                   │                   │─ create_adjustment ║▶│
    │                    │   ║                                    │◀─ increment_usage! ────────────────── │                   ║  │
    │                    │◀──║── increment_usage!(code) ──────── │                   │                   │                   ║  │
    │                    │── ║─ record_usage(promotion_code)      │                   │                   │                   ║  │
    │                    │   ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝  │
    │◀─ promotion ────── │                    │                   │                   │                   │                   │
```

### Request Flow: Auto-Apply Best Promotions

```
Host App        Evaluator       Promotion       Rules           Applicator      Actions
    │               │               │               │               │               │
    │─ eligible_promotions ────────▶│               │               │               │
    │               │─ Promotion.available ────────▶│               │               │
    │               │◀─ candidates ─────────────────│               │               │
    │               │               │               │               │               │
    │               │   ┌── for each candidate ───────────────────────────────────┐ │
    │               │── │▶ eligible?(promotable, context) ───────────────────────▶│ │
    │               │   │               │─ rule.eligible?() ──────────────────────┼▶│
    │               │   │               │◀─ true / false ──────────────────────── │ │
    │               │◀──│── true / false │               │               │         │ │
    │               │   └────────────────────────────────────────────────────────┘ │
    │◀─ eligible_promotions ──────── │               │               │               │
    │                               │               │               │               │
    │─ apply(eligible_promotions) ───────────────────────────────▶  │               │
    │               │               │               │               │               │
    │               │               │               │   ┌── for each promotion (sorted by priority) ──┐
    │               │               │               │   │  check stacking rules                       │
    │               │               │               │   │  ╔══ Transaction ════════════════════╗      │
    │               │               │               │   │  ║ action.apply(promotable) ─────── ║ ───▶ │
    │               │               │◀──────────────────│  ║ increment_usage!                 ║      │
    │               │               │               │   │  ╚══════════════════════════════════╝      │
    │               │               │               │   └─────────────────────────────────────────── ┘
```

### Service Responsibilities

| Service        | Role                                                                                                                                               | Key methods                                     |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `Evaluator`    | Determines which promotions are eligible for a given promotable. Resolves candidates either from all available promotions or from a specific code. | `eligible_promotions`, `best_promotion`         |
| `Applicator`   | Applies or removes promotion actions. Enforces stacking rules and wraps action execution in a transaction.                                         | `apply`, `apply_single`, `remove`, `remove_all` |
| `CodeRedeemer` | End-to-end coupon redemption. Validates the code, promotion status, usage limits, and per-user limits, then delegates to Applicator.               | `redeem`                                        |

## Host App Integration

Two concerns are auto-included into `ActiveRecord::Base` via the engine's `ActiveSupport.on_load(:active_record)` hook. Host models opt in by calling the class macro.

### ActsAsPromotable

Called on any model that can _receive_ discounts:

```ruby
class Order < ApplicationRecord
  acts_as_promotable
end
```

This adds:

- `has_many :promotable_adjustments` (polymorphic)
- `has_many :promotable_code_usages` (polymorphic)
- Instance methods: `apply_promotion_code`, `apply_best_promotions`, `remove_all_promotions`, `recalculate_promotions`, `promotion_total_discount`, `active_promotions`

**Interface contract** -- the host model must implement:

| Method               | Returns      | Used by                          |
| -------------------- | ------------ | -------------------------------- |
| `#promotable_amount` | `BigDecimal` | All rules and actions (required) |

**Optional contract methods** unlock the matching built-in rules and actions; missing methods are resolved through `Promotable::ContractResolver` and honor `on_missing_contract_method`:

| Method                       | Returns      | Consumers                                   |
| ---------------------------- | ------------ | ------------------------------------------- |
| `#promotable_items`          | Array-like   | `MinimumQuantityRule`, custom rules/actions |
| `#promotable_item_count`     | `Integer`    | `MinimumQuantityRule`                       |
| `#promotable_shipping_cost`  | `BigDecimal` | `FreeShippingAction`                        |
| `#promotable_country`        | `String`     | `CountryRule`                               |
| `#promotable_store_id`       | `Integer`    | `StoreRule`                                 |
| `#promotable_source`         | `String`     | `SourceRule`                                |
| `#promotable_payment_method` | `String`     | `PaymentMethodRule`                         |

### ActsAsPromoter

Called on any model that _uses_ promotions:

```ruby
class User < ApplicationRecord
  acts_as_promoter
end
```

This adds:

- `has_many :promotion_code_usages` (polymorphic)
- Instance methods: `promotion_usage_count`, `used_promotion?`, `available_promotions`

**Optional contract methods**:

| Method                      | Returns             | Consumers                               |
| --------------------------- | ------------------- | --------------------------------------- |
| `#promotable_order_count`   | `Integer`           | `FirstPurchaseRule`, `UserActivityRule` |
| `#promotable_last_order_at` | `Time` / `DateTime` | `UserActivityRule`                      |
| `#birthday`                 | `Date`              | `BirthdayRule`                          |
| `#promotion_group`          | `String`            | `AllowedUsersRule`                      |

## Extension Points

The system is designed around the Open/Closed Principle -- new behavior is added by creating new classes, never by modifying existing ones.

| Extension point          | How to extend                                                                                   | Registration                                      |
| ------------------------ | ----------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| New eligibility rule     | Subclass `Promotable::Rules::Base`, implement `#evaluate`, declare `requires_context` if needed | `config.rule_registry.register(:key, MyRule)`     |
| New discount action      | Subclass `Promotable::Actions::Base`, implement `#compute_amount` and `#apply`                  | `config.action_registry.register(:key, MyAction)` |
| New promotable model     | Call `acts_as_promotable`, implement `#promotable_amount`                                       | None needed                                       |
| New promoter model       | Call `acts_as_promoter`                                                                         | None needed                                       |
| New host contract method | Consumers reach it through `Promotable::ContractResolver.call(target, :method_name)`            | Add to `OPTIONAL_CONTRACT_METHODS` on the concern |
| New tenant model         | Set `config.tenant_model_name = "Account"` in the initializer                                   | N/A -- the `client_id` FK is resolved dynamically |
| Configuration            | `Promotable.configure { \|c\| ... }`                                                            | N/A                                               |

### Extension example: custom rule

```ruby
class GeoLocationRule < Promotable::Rules::Base
  requires_context :user

  store_accessor :preferences, :allowed_countries

  validates :allowed_countries, presence: true, on: :rule_validation

  private

  def evaluate(_promotable, context)
    country = Promotable::ContractResolver.call(context[:user], :country)
    return false if country.nil?

    Array(allowed_countries).map(&:upcase).include?(country.to_s.upcase)
  end
end
```

```ruby
# config/initializers/promotable.rb
Promotable.configure do |config|
  config.rule_registry.register(:geo_location, GeoLocationRule)
end
```

No gem code is modified. The rule is persisted via STI in `promotable_rules`, its configuration stored in the `preferences` JSON column, and its access to `context[:user]` is enforced by `requires_context` (raising `MissingContextError` if a caller forgets to pass it). Missing `#country` on the user follows `on_missing_contract_method` — no more silent `NoMethodError`.

## File Structure

```
promotable/
├── app/models/promotable/
│   ├── application_record.rb        # Abstract base for all engine models
│   ├── promotion.rb                 # Core promotion entity (tenant-scoped)
│   ├── promotion_code.rb            # Redeemable coupon codes (tenant-scoped)
│   ├── code_usage.rb                # Polymorphic usage tracking (tenant-scoped)
│   ├── adjustment.rb                # Polymorphic discount records (tenant-scoped)
│   ├── rules/
│   │   ├── base.rb                  # STI base — #eligible? / #evaluate / requires_context
│   │   ├── minimum_amount_rule.rb   # promotable_amount >= threshold
│   │   ├── maximum_amount_rule.rb   # promotable_amount <= threshold
│   │   ├── minimum_quantity_rule.rb # item count >= threshold
│   │   ├── country_rule.rb          # promotable_country ∈ allow-list
│   │   ├── store_rule.rb            # promotable_store_id ∈ allow-list
│   │   ├── source_rule.rb           # promotable_source ∈ allow-list
│   │   ├── payment_method_rule.rb   # promotable_payment_method ∈ allow-list
│   │   ├── product_variant_rule.rb  # variant include/exclude on line items
│   │   ├── category_rule.rb         # category include/exclude on line items
│   │   ├── time_window_rule.rb      # day-of-week + hour-of-day window
│   │   ├── first_purchase_rule.rb   # user's first order
│   │   ├── new_user_rule.rb         # user created within N days
│   │   ├── user_activity_rule.rb    # order count + recency thresholds
│   │   ├── allowed_users_rule.rb    # explicit user_id/group allow-list
│   │   ├── frequency_rule.rb        # max N uses per day/week/month/ever
│   │   └── birthday_rule.rb         # eligible on birthday ± window_days
│   └── actions/
│       ├── base.rb                  # STI base — #apply / #undo / #compute_amount / #adjustment_label
│       ├── percentage_discount.rb   # X% off promotable_amount
│       ├── fixed_amount_discount.rb # flat currency amount off, capped at total
│       ├── capped_percentage_discount.rb  # percentage with an absolute ceiling
│       ├── free_shipping_action.rb  # discounts promotable_shipping_cost
│       └── tiered_discount_action.rb  # picks highest matching min_amount tier
│
├── db/migrate/
│   ├── 20260409000001_create_promotable_tables.rb    # Initial 6 tables
│   ├── 20260722000002_add_client_to_promotable_promotions.rb  # tenant column (interim)
│   └── 20260726000003_denormalize_client_to_promotable_records.rb  # denormalized client_id on children
│
├── lib/
│   ├── promotable.rb                # Entry point, configure/reset
│   └── promotable/
│       ├── version.rb               # Gem version
│       ├── engine.rb                # Rails::Engine, Railtie hooks, acts_as_tenant wiring
│       ├── configuration.rb         # Configuration DSL, lazy registries, register_defaults!
│       ├── registry.rb              # Thread-safe, reload-safe type registry
│       ├── errors.rb                # Error class hierarchy
│       ├── contract_resolver.rb     # Resolves optional host methods per configured policy
│       ├── tenant_scoped.rb         # Concern that wires acts_as_tenant on tenant models
│       ├── acts_as_promotable.rb    # Concern for promotable models (required/optional contract)
│       ├── acts_as_promoter.rb      # Concern for user/promoter models
│       ├── evaluator.rb             # Finds eligible promotions (tenant-scoped)
│       ├── applicator.rb            # Applies/removes promotions, syncs total_after_discounts
│       └── code_redeemer.rb         # End-to-end coupon redemption (tenant-scoped)
│
├── lib/generators/promotable/
│   ├── install/                     # rails g promotable:install [--tenant-model] [--require-tenant]
│   ├── rule/                        # rails g promotable:rule NAME [--requires-context]
│   └── action/                      # rails g promotable:action NAME
│
├── lib/tasks/
│   └── promotable_tasks.rake        # rake promotable:stats
│
├── config/
│   ├── routes.rb                    # Mounts Avo admin (mount_avo)
│   └── initializers/avo.rb          # Avo configuration for the admin panel
│
└── spec/
    ├── dummy/                       # Rails 8 dummy app used by the spec suite
    │   ├── app/models/              # Client, Order, LineItem, User (with acts_as_promotable / _promoter)
    │   ├── app/avo/resources/       # Avo admin resources for every model
    │   └── db/                      # schema.rb + spec-only migrations
    ├── models/                      # Model specs mirror app/models/promotable/
    ├── services/                    # Evaluator, Applicator, CodeRedeemer specs
    ├── multitenancy_spec.rb         # Cross-tenant leak-proof invariants
    ├── concerns_spec.rb             # ActsAsPromotable / ActsAsPromoter behavior
    ├── configuration_spec.rb        # Configuration DSL and defaults
    ├── registry_spec.rb             # Registry behavior + reload safety
    ├── dummy_host_models_spec.rb    # Host contract validation
    └── promotable_spec.rb           # Top-level Promotable module
```

## Error Hierarchy

All errors descend from `Promotable::Error` for catch-all rescue:

```
Promotable::Error
├── InvalidCodeError            # code string not found in the current tenant scope
├── IneligibleError             # promotion fails eligibility
├── PromotionInactiveError      # active flag is false
├── PromotionExpiredError       # outside date range
├── UsageLimitExceededError     # code, promotion, or per-user limit
├── StackingNotAllowedError     # stacking disabled, already has a promo
├── PromotableInterfaceError    # host missing a required contract method
├── MissingContextError         # rule declared requires_context but caller omitted a key
└── ContractError               # on_missing_contract_method = :raise and an optional method is missing
```

## Contributing to the Architecture

This document is the source of truth for the shape of the system. If you make a change that alters any of the following, update the relevant section before opening a PR:

- **A new design pattern** or a new class of extension point → add a numbered subsection under [Design Patterns](#design-patterns) and a row to the [Extension Points](#extension-points) table.
- **A schema change** (new column, new table, new index, changed uniqueness constraint) → update the [Data Model](#data-model) ER diagram and add / edit a row in the "Key design decisions" table explaining the rationale.
- **A new service or lifecycle step** → update the sequence diagrams in [Service Layer](#service-layer) and add the service to the "Service Responsibilities" table.
- **A new required or optional contract method** → update [Host App Integration](#host-app-integration) so consumers know what to implement, and add the method to `REQUIRED_CONTRACT_METHODS` / `OPTIONAL_CONTRACT_METHODS` on the relevant concern.
- **A new file under `lib/promotable/`, `app/models/promotable/`, or `lib/generators/promotable/`** → add a line to [File Structure](#file-structure) so newcomers can navigate.
- **A new error class** → add it to [Error Hierarchy](#error-hierarchy) and to the error table in README.

The README covers the day-to-day contributor workflow (branching, testing, code style, PR checklist). This document covers the architectural rules that determine _where_ new code should land.
