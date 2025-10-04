class AddRecordPolymorphismToVarbinds < ActiveRecord::Migration[8.0]
  def change
    # Add polymorphic record reference
    add_column :varbinds, :record_type, :string
    add_column :varbinds, :record_id, :bigint
    
    # Add indexes for the new polymorphic association
    add_index :varbinds, [:record_type, :record_id]
    
    # Update unique constraint to include record
    remove_index :varbinds, [:varbindable_type, :varbindable_id] if index_exists?(:varbinds, [:varbindable_type, :varbindable_id])
    add_index :varbinds, [:varbindable_type, :varbindable_id, :record_type, :record_id, :value], 
              unique: true, 
              name: "index_varbinds_on_varbindable_record_and_value"
    
    # Backfill existing records: set record_type='Variant', record_id=variant_id
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE varbinds 
          SET record_type = 'Variant', record_id = variant_id 
          WHERE record_type IS NULL
        SQL
      end
    end
    
    # Make record fields non-null after backfill
    change_column_null :varbinds, :record_type, false
    change_column_null :varbinds, :record_id, false
  end
end
