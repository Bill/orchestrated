# borrowed from delayed_job_active_record, and modified…
require 'rails/generators/migration'
require 'rails/generators/active_record/migration'

# Extend the DelayedJobGenerator so that it creates an AR migration
module Orchestrated
  class ActiveRecordGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    extend ActiveRecord::Generators::Migration

    self.source_paths << File.join(File.dirname(__FILE__), 'templates')

    def create_migration_file
      migration_template 'migration.rb', 'db/migrate/create_orchestrated.rb'
    end
  end
end
