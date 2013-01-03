# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'orchestrated/version'

Gem::Specification.new do |gem|
  gem.name          = "orchestrated"
  gem.version       = Orchestrated::VERSION
  gem.authors       = ["Bill Burcham"]
  gem.email         = ["bill@paydici.com"]
  gem.description   = %q{a workflow orchestration framework running on delayed_job and active_record}
  gem.summary       = %q{Orchestrated is a workflow orchestration framework running on delayed_job and active_record. In the style of delayed_job's 'delay', Orchestration lets you 'orchestrate' delivery of a message so that it will run only after others have been delivered and processed.}
  gem.homepage      = "https://github.com/paydici/orchestration"
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency     'delayed_job_active_record', '~> 0.3'
  gem.add_runtime_dependency     'activerecord', ['>= 3']
  gem.add_runtime_dependency     'state_machine', ['>= 1']

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rails', ['>= 3'] # for rspec-rails
  gem.add_development_dependency 'rspec-rails'
  # I couldn't get rspecs transactional fixtures setting to do savepoints
  # in this project (which is not _really_ a Rails app). database_cleaner
  # claims it'll help us clean up the database so let's try it!
  gem.add_development_dependency 'database_cleaner'
  gem.add_development_dependency 'sqlite3'
end
