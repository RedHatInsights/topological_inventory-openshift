source 'https://rubygems.org'

gem "activesupport"
gem "concurrent-ruby"
gem "kubeclient", :git => "https://github.com/abonas/kubeclient", :branch => "master"
gem "optimist"
gem "rake"
gem "topological_inventory-ingress_api-client", :git => "https://github.com/ManageIQ/topological_inventory-ingress_api-client-ruby", :branch => "master"
gem "more_core_extensions"

group :test do
  gem "rspec-core"
end

#
# Custom Gemfile modifications
#
# To develop a gem locally and override its source to a checked out repo
#   you can use this helper method in Gemfile.dev.rb e.g.
#
# override_gem 'topological_inventory-ingress_api-client', :path => "../topological_inventory-ingress_api-client"
#
def override_gem(name, *args)
  if dependencies.any?
    raise "Trying to override unknown gem #{name}" unless (dependency = dependencies.find { |d| d.name == name })
    dependencies.delete(dependency)

    calling_file = caller_locations.detect { |loc| !loc.path.include?("lib/bundler") }.path
    calling_dir  = File.dirname(calling_file)

    args.last[:path] = File.expand_path(args.last[:path], calling_dir) if args.last.kind_of?(Hash) && args.last[:path]
    gem(name, *args).tap do
      warn "** override_gem: #{name}, #{args.inspect}, caller: #{calling_file}" unless ENV["RAILS_ENV"] == "production"
    end
  end
end

# Load other additional Gemfiles
#   Developers can create a file ending in .rb under bundler.d/ to specify additional development dependencies
Dir.glob(File.join(__dir__, 'bundler.d/*.rb')).each { |f| eval_gemfile(File.expand_path(f, __dir__)) }
