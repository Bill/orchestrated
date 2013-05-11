# Get Rails environment going. Borrowed from delayed_job_active_record project, then heavily modified
# ...

$:.unshift(File.join( File.dirname(__FILE__), '../lib'))

require 'rubygems'
require 'bundler/setup'

require 'simplecov'
SimpleCov.start do
  add_group "Orchestrated", "lib/orchestrated"
end

require 'rails/all' # rspec/rails needs Rails
require 'rspec/rails' # we want transactional fixtures!

require 'logger'

require 'delayed_job'
require 'rails'

Delayed::Worker.logger = Logger.new('/tmp/dj.log')
ENV['RAILS_ENV'] = 'test'

config = YAML.load(File.read('spec/database.yml'))
ActiveRecord::Base.establish_connection config['test']
ActiveRecord::Base.logger = Delayed::Worker.logger
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
    create_table :delayed_jobs, :force => true do |table|
      table.integer  :priority, :default => 0      # Allows some jobs to jump to the front of the queue
      table.integer  :attempts, :default => 0      # Provides for retries, but still fail eventually.
      table.text     :handler                      # YAML-encoded string of the object that will do work
      table.text     :last_error                   # reason for last failure (See Note below)
      table.datetime :run_at                       # When to run. Could be Time.zone.now for immediately, or sometime in the future.
      table.datetime :locked_at                    # Set when a client is working on this object
      table.datetime :failed_at                    # Set when all retries have failed (actually, by default, the record is deleted instead)
      table.string   :locked_by                    # Who is working on this object (if locked)
      table.string   :queue                        # The name of the queue this job is in
      table.timestamps
    end

    add_index :delayed_jobs, [:priority, :run_at], :name => 'delayed_jobs_priority'

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

# Add this directory so the ActiveSupport autoloading works
ActiveSupport::Dependencies.autoload_paths << File.dirname(__FILE__)

# when we run via plain old "ruby" command instead of "rspec", this
# line tells ruby to run the examples
require 'rspec/autorun'

# This is the present Ruby Gem: the one we are spec-ing/testing
require 'orchestrated'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join( File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f}
require 'delayed_job_facade'
require 'spec_helper_methods'

require 'database_cleaner' # see comments below

RSpec.configure do |config|

  # This standard Rails approach won't work in this project (which is not
  # _really_ a Rails app after all.
  #   config.use_transactional_fixtures = true
  # So we are trying the database_cleaner gem instead:
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  # Use color in STDOUT
  config.color_enabled = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :progress # :documentation :progress, :html, :textmate

  config.include SpecHelperMethods
end
