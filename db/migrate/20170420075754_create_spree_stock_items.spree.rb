# This migration comes from spree (originally 20130211190146)
class CreateSpreeStockItems < ActiveRecord::Migration
  def change
    create_table :spree_stock_items do |t|
      t.belongs_to :stock_location
      t.belongs_to :variant
      t.integer :count_on_hand
      t.integer :lock_version

      t.timestamps
    end
    add_index :spree_stock_items, :stock_location_id
    add_index :spree_stock_items, [:stock_location_id, :variant_id]
  end
end
