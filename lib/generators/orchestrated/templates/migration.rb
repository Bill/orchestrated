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
    create_table :composited_completions do |table|
      table.references :composite_completion
      table.references :completion_expression
    end
  end

  def self.down
    drop_table :composited_completions
    drop_table :completion_expressions
    drop_table :orchestrations
  end
end
