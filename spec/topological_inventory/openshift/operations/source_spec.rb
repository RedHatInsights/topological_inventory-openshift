require "topological_inventory/openshift/operations/source"
require File.join(Gem::Specification.find_by_name("topological_inventory-providers-common").gem_dir, "spec/support/shared/availability_check.rb")

RSpec.describe(TopologicalInventory::Openshift::Operations::Source) do
  it_behaves_like "availability_check" # in providers-common
end
