class CreateOrchestrated < ActiveRecord::Migration
  def self.up
    create_table :orchestrations do |table|
      table.string     :state
      table.text       :handler
      table.references :prerequisite
      table.references :delayed_job, :polymorphic => true
      table.timestamps
    end
    create_table :completion_expressions do |table|
      table.string     :type
      # only one kind of completion expression needs this
      # (OrchestrationCompletion) but I didn't want to put
      # it in a separate table because it would really contort
      # the Rails model
      table.references :orchestration
    end
    create_table :orchestration_dependencies do |table|
      table.string     :state
      table.references :dependent
      table.references :prerequisite
    end
  end

  def self.down
    drop_table :orchestration_dependencies
    drop_table :completion_expressions
    drop_table :orchestrations
  end
end
