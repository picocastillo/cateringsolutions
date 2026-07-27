class DropAuditsTable < ActiveRecord::Migration[5.2]
  def up
    drop_table :audits
  end

  def down
    create_table :audits, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer :auditable_id
      t.string :auditable_type
      t.integer :associated_id
      t.string :associated_type
      t.integer :user_id
      t.string :user_type
      t.string :username
      t.string :action
      t.text :audited_changes
      t.integer :version, default: 0
      t.string :comment
      t.string :remote_address
      t.string :request_uuid
      t.datetime :created_at
    end

    add_index :audits, :request_uuid
    add_index :audits, :created_at
  end
end
