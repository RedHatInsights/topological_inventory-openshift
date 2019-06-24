source 'https://rubygems.org'

plugin 'bundler-inject', '~> 1.1'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

gem "activesupport", "~> 5.2.2"
gem "cloudwatchlogger", "~> 0.2"
gem "concurrent-ruby"
gem "config"
gem "more_core_extensions"
gem "optimist"
gem "prometheus_exporter", "~> 0.4.5"
gem "rake"

gem "kubeclient", :git => "https://github.com/abonas/kubeclient", :branch => "master"
gem "manageiq-loggers", "~> 0.3.0"
gem "manageiq-messaging", "~> 0.1.2"
gem "sources-api-client",                       :git => "https://github.com/ManageIQ/sources-api-client-ruby", :branch => "master"
gem 'topological_inventory-api-client',         :git => "https://github.com/ManageIQ/topological_inventory-api-client-ruby", :branch => "master"
gem "topological_inventory-ingress_api-client", :git => "https://github.com/ManageIQ/topological_inventory-ingress_api-client-ruby", :branch => "master"

group :development, :test do
  gem "rspec"
  gem "simplecov"
  gem "webmock"
end
