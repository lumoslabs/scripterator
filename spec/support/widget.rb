require 'active_record'

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveRecord::Migration.create_table :widgets do |t|
  t.string :name
  t.timestamps
end

class Widget < ActiveRecord::Base
  def self.before_stuff; end
  def self.widget_code(widget); true; end
end
