require "rails_helper"

# Cross-tenant leak-proof invariant: for every read path and every write path
# in the gem, an operation performed as tenant A must never touch, discover,
# or mutate data belonging to tenant B. Global rows (client_id: nil) are the
# only shared surface; tests reserve one dedicated global promotion to prove
# it stays visible across both tenants.
RSpec.describe "Promotable multitenancy leak-proofness" do
  let(:acme)   { create_client(name: "Acme")   }
  let(:globex) { create_client(name: "Globex") }

  let!(:acme_promo) do
    ActsAsTenant.with_tenant(acme) { create_promotion(name: "Acme 10%", client: acme) }
  end
  let!(:globex_promo) do
    ActsAsTenant.with_tenant(globex) { create_promotion(name: "Globex 10%", client: globex) }
  end
  let!(:global_promo) { create_promotion(name: "Global 5%") }

  describe "Promotion.all default_scope" do
    it "returns only tenant + global rows when a tenant is set" do
      ActsAsTenant.with_tenant(acme) do
        expect(Promotable::Promotion.all.pluck(:name)).to contain_exactly("Acme 10%", "Global 5%")
      end

      ActsAsTenant.with_tenant(globex) do
        expect(Promotable::Promotion.all.pluck(:name)).to contain_exactly("Globex 10%", "Global 5%")
      end
    end
  end

  describe "PromotionCode default_scope" do
    let!(:acme_code)   { ActsAsTenant.with_tenant(acme)   { Promotable::PromotionCode.create!(promotion: acme_promo,   code: "SAVE10") } }
    let!(:globex_code) { ActsAsTenant.with_tenant(globex) { Promotable::PromotionCode.create!(promotion: globex_promo, code: "SAVE10") } }
    let!(:global_code) { Promotable::PromotionCode.create!(promotion: global_promo, code: "GLOBAL5") }

    it "allows the same code string per tenant" do
      expect(acme_code).to be_persisted
      expect(globex_code).to be_persisted
      expect(acme_code.code).to eq(globex_code.code)
    end

    it "scopes lookups to the current tenant + globals" do
      ActsAsTenant.with_tenant(acme) do
        expect(Promotable::PromotionCode.pluck(:code)).to contain_exactly("SAVE10", "GLOBAL5")
      end

      ActsAsTenant.with_tenant(globex) do
        expect(Promotable::PromotionCode.pluck(:code)).to contain_exactly("SAVE10", "GLOBAL5")
      end
    end
  end

  describe "Adjustment default_scope" do
    let!(:acme_order)   { create_order(client: acme,   total_amount: 100) }
    let!(:globex_order) { create_order(client: globex, total_amount: 100) }

    let!(:acme_adjustment) do
      ActsAsTenant.with_tenant(acme) do
        action = Promotable::Actions::PercentageDiscount.create!(promotion: acme_promo, preferences: { percentage: 10 })
        Promotable::Adjustment.create!(
          promotion: acme_promo,
          promotion_action: action,
          adjustable: acme_order,
          amount: -10,
          label: "Acme 10%"
        )
      end
    end

    let!(:globex_adjustment) do
      ActsAsTenant.with_tenant(globex) do
        action = Promotable::Actions::PercentageDiscount.create!(promotion: globex_promo, preferences: { percentage: 10 })
        Promotable::Adjustment.create!(
          promotion: globex_promo,
          promotion_action: action,
          adjustable: globex_order,
          amount: -10,
          label: "Globex 10%"
        )
      end
    end

    it "does not surface another tenant's adjustments" do
      ActsAsTenant.with_tenant(acme) do
        expect(Promotable::Adjustment.pluck(:label)).to contain_exactly("Acme 10%")
      end

      ActsAsTenant.with_tenant(globex) do
        expect(Promotable::Adjustment.pluck(:label)).to contain_exactly("Globex 10%")
      end
    end
  end

  describe "child records inherit client_id from their promotion" do
    it "propagates the tenant to codes and adjustments on create" do
      ActsAsTenant.with_tenant(acme) do
        code = Promotable::PromotionCode.create!(promotion: acme_promo, code: "INHERIT")
        expect(code.client_id).to eq(acme.id)

        action = Promotable::Actions::PercentageDiscount.create!(promotion: acme_promo, preferences: { percentage: 5 })
        adjustment = Promotable::Adjustment.create!(
          promotion: acme_promo,
          promotion_action: action,
          adjustable: create_order(client: acme, total_amount: 50),
          amount: -2.5,
          label: "Inherit 5%"
        )
        expect(adjustment.client_id).to eq(acme.id)
      end
    end

    it "cannot be persisted with a client that mismatches its promotion" do
      # Simulate a direct write (e.g. via `assign_attributes` after callbacks)
      # by using a save! flow that bypasses the before_validation inherit hook.
      other_tenant_id = globex.id
      ActsAsTenant.with_tenant(acme) do
        code = Promotable::PromotionCode.new(promotion: acme_promo, code: "BAD")
        # Force a mismatch AFTER inherit_client_from_promotion has fired.
        code.define_singleton_method(:inherit_client_from_promotion) { self.client_id = other_tenant_id }
        expect(code).not_to be_valid
        expect(code.errors[:client_id]).to include(a_string_matching(/must match/))
      end
    end
  end

  describe "cascades client_id to children when a global promotion is retroactively scoped" do
    it "propagates the new client_id down to codes, usages, and adjustments" do
      promo = create_promotion(name: "Retro")
      code  = Promotable::PromotionCode.create!(promotion: promo, code: "RETRO")
      action = Promotable::Actions::PercentageDiscount.create!(promotion: promo, preferences: { percentage: 5 })
      order = create_order(client: acme, total_amount: 50)
      adjustment = Promotable::Adjustment.create!(
        promotion: promo,
        promotion_action: action,
        adjustable: order,
        amount: -2.5,
        label: "Retro 5%"
      )

      expect(code.client_id).to be_nil
      expect(adjustment.client_id).to be_nil

      promo.update!(client: acme)

      expect(code.reload.client_id).to eq(acme.id)
      expect(adjustment.reload.client_id).to eq(acme.id)
    end
  end

  describe "Evaluator" do
    it "surfaces only the calling tenant's + global promotions" do
      order = create_order(client: acme, total_amount: 100)
      results = Promotable::Evaluator.new(order, client: acme).eligible_promotions.map(&:name)

      expect(results).to contain_exactly("Acme 10%", "Global 5%")
    end
  end

  describe "CodeRedeemer" do
    before do
      ActsAsTenant.with_tenant(acme)   { Promotable::PromotionCode.create!(promotion: acme_promo,   code: "ACMECODE") }
      ActsAsTenant.with_tenant(globex) { Promotable::PromotionCode.create!(promotion: globex_promo, code: "GLOBEXCODE") }
      Promotable::Actions::PercentageDiscount.create!(promotion: acme_promo,   preferences: { percentage: 10 })
      Promotable::Actions::PercentageDiscount.create!(promotion: globex_promo, preferences: { percentage: 10 })
    end

    it "refuses cross-tenant redemption" do
      acme_order = create_order(client: acme, total_amount: 100)
      acme_user  = create_user(client: acme)

      redeemer = Promotable::CodeRedeemer.new("GLOBEXCODE", promotable: acme_order, user: acme_user, client: acme)
      expect { redeemer.redeem }.to raise_error(Promotable::InvalidCodeError)
    end
  end

  describe "Applicator" do
    it "only sees its own tenant's adjustments when removing" do
      shared_order = create_order(client: acme, total_amount: 100)
      Promotable::Actions::PercentageDiscount.create!(promotion: acme_promo, preferences: { percentage: 10 })

      ActsAsTenant.with_tenant(acme) do
        Promotable::Applicator.new(shared_order, client: acme).apply(acme_promo)
      end

      cross_tenant_view = ActsAsTenant.with_tenant(globex) do
        Promotable::Adjustment.for_promotable(shared_order).to_a
      end

      expect(cross_tenant_view).to be_empty
    end
  end
end
