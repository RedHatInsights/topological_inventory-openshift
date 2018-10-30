$:.push File.expand_path("../lib", __FILE__)

require "openshift-collector/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openshift-collector"
  s.version     = OpenshiftCollector::VERSION
  s.authors     = ["Adam Grare"]
  s.email       = ["agrare@redhat.com"]
  s.homepage    = "https://github.com/agrare/openshift-collector"
  s.summary     = "OpenShift collector for the Topological Inventory Service."
  s.description = "OpenShift collector for the Topological Inventory Service."
  s.license     = "Apache-2.0"

  s.files = Dir["{lib}/**/*"]

  s.add_dependency "activesupport"
  s.add_dependency "concurrent-ruby"
  s.add_dependency "kubeclient"
  s.add_dependency "optimist"
end
