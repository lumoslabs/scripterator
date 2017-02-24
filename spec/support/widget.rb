require 'active_record'

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveRecord::Migration.create_table :widgets do |t|
  t.string :name
  t.timestamps
end

class Widget < ActiveRecord::Base
  # some dummy methods for setting message expectations in specs
  def self.before_stuff; end
  def self.after_batch_stuff(batch); end
  def self.transform_a_widget(widget); true; end
end
