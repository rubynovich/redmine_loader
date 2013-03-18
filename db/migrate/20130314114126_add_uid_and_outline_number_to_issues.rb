class AddUidAndOutlineNumberToIssues < ActiveRecord::Migration
  def self.up
    add_column :issues, :uid, :integer, :default => nil, :null => true
    add_column :versions, :uid, :integer, :default => nil, :null => true
  end

  def self.down
    remove_column :issues, :uid
    remove_column :versions, :uid
  end
end
