source 'https://rubygems.org'

plugin 'bundler-inject', '~> 1.1'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

gem "activesupport", "~> 5.2.2"
gem "cloudwatchlogger", "~> 0.2"
gem "concurrent-ruby"
gem "http", "~> 4.1.1"
gem "more_core_extensions"
gem "optimist"
gem "prometheus_exporter", "~> 0.4.5"
gem "rake"

gem "kubeclient", :git => "https://github.com/abonas/kubeclient", :branch => "master"
gem "manageiq-loggers", "~> 0.4.0", ">= 0.4.2"
gem "manageiq-messaging", "~> 0.1.2"
gem "sources-api-client", "~> 1.0"
gem 'topological_inventory-api-client',         "~> 3.0"
gem "topological_inventory-ingress_api-client", "~> 1.0.1"
gem "topological_inventory-providers-common", "~> 1.0.0"

group :development, :test do
  gem "rspec"
  gem "simplecov"
  gem "webmock"
end
