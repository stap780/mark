class UpdateSwatchGroupStyleDefaults < ActiveRecord::Migration[7.2]
  def up
    change_column_default :swatch_groups, :product_page_style, from: "circular", to: "circular_small_desktop"
    change_column_default :swatch_groups, :collection_page_style, from: "circular_small", to: "circular_small_mobile"

    # Backfill existing NULL or legacy values to new defaults for consistency
    execute <<~SQL.squish
      UPDATE swatch_groups
      SET product_page_style = 'circular_small_desktop'
      WHERE product_page_style IS NULL OR product_page_style = 'circular';
    SQL

    execute <<~SQL.squish
      UPDATE swatch_groups
      SET collection_page_style = 'circular_small_mobile'
      WHERE collection_page_style IS NULL OR collection_page_style = 'circular_small';
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE swatch_groups
      SET product_page_style = 'circular'
      WHERE product_page_style = 'circular_small_desktop';
    SQL

    execute <<~SQL.squish
      UPDATE swatch_groups
      SET collection_page_style = 'circular_small'
      WHERE collection_page_style = 'circular_small_mobile';
    SQL

    change_column_default :swatch_groups, :product_page_style, from: "circular_small_desktop", to: "circular"
    change_column_default :swatch_groups, :collection_page_style, from: "circular_small_mobile", to: "circular_small"
  end
end
