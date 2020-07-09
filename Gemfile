source 'https://rubygems.org'

plugin 'bundler-inject', '~> 1.1'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

gem "activesupport", '~> 5.2.4.3'
gem "cloudwatchlogger", "~> 0.2"
gem "concurrent-ruby"
gem "http", "~> 4.1.1"
gem "more_core_extensions"
gem "optimist"
gem "prometheus_exporter", "~> 0.4.5"
gem "rake", ">= 12.3.3"

gem "kubeclient", :git => "https://github.com/abonas/kubeclient", :branch => "master"
gem "manageiq-loggers", "~> 0.5.0"
gem "manageiq-messaging", "~> 0.1.5"
gem "sources-api-client", "~> 3.0"
gem 'topological_inventory-api-client',         "~> 3.0"
gem "topological_inventory-ingress_api-client", "~> 1.0.1"
gem "topological_inventory-providers-common", "~> 1.0.6"

group :development, :test do
  gem "rspec"
  gem 'rubocop',             "~>0.69.0", :require => false
  gem 'rubocop-performance', "~>1.3",    :require => false
  gem "simplecov",           "~>0.17.1"
  gem "webmock"
end
