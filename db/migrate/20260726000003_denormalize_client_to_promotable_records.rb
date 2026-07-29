class DenormalizeClientToPromotableRecords < ActiveRecord::Migration[8.1]
  # Establishes the tenant column layout used by acts_as_tenant:
  #
  #   * promotable_promotions.client_id is a plain bigint (no client_type).
  #   * promotable_promotion_codes / _code_usages / _adjustments each carry
  #     their own client_id column so acts_as_tenant can enforce isolation
  #     at every layer without joining back to the promotion.
  #   * promotable_promotion_codes.code becomes unique per (client_id, code)
  #     so different tenants can reuse the same coupon string.
  #
  # The FK to the tenant table is added only if the configured tenant table
  # exists in the target DB, so host apps whose tenant model isn't named
  # "Client" (see Promotable.configuration.tenant_model_name) still migrate
  # cleanly.
  #
  # NOTE: No data backfill is performed. The gem is greenfield — there are no
  # existing rows to migrate. Host apps installing after real usage should
  # extend this migration (or add their own) to populate client_id before
  # relying on acts_as_tenant enforcement.
  def up
    convert_promotions_to_plain_client!
    add_client_id_column!(:promotable_promotion_codes)
    add_client_id_column!(:promotable_code_usages)
    add_client_id_column!(:promotable_adjustments)

    reindex_promotion_codes_by_client_and_code!
  end

  def down
    restore_promotion_codes_unique_on_code_only!

    [ :promotable_promotion_codes, :promotable_code_usages, :promotable_adjustments ].each do |table|
      next unless column_exists?(table, :client_id)

      if tenant_table_name && foreign_key_exists?(table, tenant_table_name, column: :client_id)
        remove_foreign_key table, tenant_table_name, column: :client_id
      end
      remove_index table, name: "index_#{table}_on_client_id" if index_name_exists?(table, "index_#{table}_on_client_id")
      remove_column table, :client_id
    end

    return if column_exists?(:promotable_promotions, :client_type)

    if tenant_table_name && foreign_key_exists?(:promotable_promotions, tenant_table_name, column: :client_id)
      remove_foreign_key :promotable_promotions, tenant_table_name, column: :client_id
    end
    remove_index :promotable_promotions, name: "index_promotable_promotions_on_client_id" if index_name_exists?(:promotable_promotions, "index_promotable_promotions_on_client_id")
    add_column :promotable_promotions, :client_type, :string
    add_index :promotable_promotions, [ :client_type, :client_id ], name: "index_promotable_promotions_on_client"
  end

  private

  def convert_promotions_to_plain_client!
    return unless column_exists?(:promotable_promotions, :client_type)

    remove_index :promotable_promotions, name: "index_promotable_promotions_on_client" if index_name_exists?(:promotable_promotions, "index_promotable_promotions_on_client")
    remove_column :promotable_promotions, :client_type
    add_index :promotable_promotions, :client_id, name: "index_promotable_promotions_on_client_id"

    add_tenant_foreign_key(:promotable_promotions)
  end

  def add_client_id_column!(table)
    unless column_exists?(table, :client_id)
      add_column table, :client_id, :bigint
      add_index  table, :client_id, name: "index_#{table}_on_client_id"
    end

    add_tenant_foreign_key(table)
  end

  def add_tenant_foreign_key(table)
    return unless tenant_table_name && data_source_exists?(tenant_table_name)
    return if foreign_key_exists?(table, tenant_table_name, column: :client_id)

    add_foreign_key table, tenant_table_name, column: :client_id
  end

  def reindex_promotion_codes_by_client_and_code!
    if index_name_exists?(:promotable_promotion_codes, "index_promotable_promotion_codes_on_code")
      remove_index :promotable_promotion_codes, name: "index_promotable_promotion_codes_on_code"
    end

    unless index_name_exists?(:promotable_promotion_codes, "index_promotable_promotion_codes_on_client_id_and_code")
      add_index :promotable_promotion_codes, [ :client_id, :code ],
                unique: true,
                name: "index_promotable_promotion_codes_on_client_id_and_code"
    end
  end

  def restore_promotion_codes_unique_on_code_only!
    if index_name_exists?(:promotable_promotion_codes, "index_promotable_promotion_codes_on_client_id_and_code")
      remove_index :promotable_promotion_codes, name: "index_promotable_promotion_codes_on_client_id_and_code"
    end
    unless index_name_exists?(:promotable_promotion_codes, "index_promotable_promotion_codes_on_code")
      add_index :promotable_promotion_codes, :code, unique: true, name: "index_promotable_promotion_codes_on_code"
    end
  end

  def tenant_model_name
    (defined?(Promotable) && Promotable.configuration&.tenant_model_name.presence) || "Client"
  end

  def tenant_table_name
    tenant_model_name.tableize
  end

  def index_name_exists?(table, name)
    connection.index_name_exists?(table, name)
  end
end
