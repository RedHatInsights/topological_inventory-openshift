RSpec.describe TopologicalInventory::Openshift::Parser do
  let(:parser) { described_class.new(:openshift_host => "localhost") }

  context "#parse_base_item" do
    let(:entity) do
      Kubeclient::Resource.new(
        :metadata => {
          :name            => "my-entity",
          :resourceVersion => "1",
          :uid             => "db590ed3-e74d-41ce-a3ec-5a9ea24c1eb9"
        }
      )
    end

    it "with a simple entity" do
      expect(parser.send(:parse_base_item, entity)).to include(
        :name             => "my-entity",
        :resource_version => "1",
        :source_ref       => "db590ed3-e74d-41ce-a3ec-5a9ea24c1eb9"
      )
    end
  end

  context "#archive_entity" do
    let(:deleted_at) { Time.now.utc }
    let(:deleted_entity) do
      Kubeclient::Resource.new(
        :metadata => {
          :deletionTimestamp => deleted_at
        }
      )
    end

    it "sets source_deleted_at" do
      inventory_object = TopologicalInventoryIngressApiClient::ContainerGroup.new
      parser.send(:archive_entity, inventory_object, deleted_entity)

      expect(inventory_object.source_deleted_at).to eq(deleted_at)
    end
  end

  context "#lazy_find" do
    it "creates an InventoryObjectLazy object" do
      lazy_ref = parser.send(:lazy_find, parser.collections[:container_groups], :source_ref => "abcd")
      expect(lazy_ref).to be_a(TopologicalInventoryIngressApiClient::InventoryObjectLazy)
      expect(lazy_ref.inventory_collection_name.name).to eq(:container_groups)
      expect(lazy_ref.reference).to                      eq(:source_ref => "abcd")
      expect(lazy_ref.ref).to                            eq(:manager_ref)
    end
  end

  context "#lazy_find_namespace" do
    let(:lazy_ref) { parser.send(:lazy_find_namespace, "my-namespace") }
    it "defaults to container_projects" do
      expect(lazy_ref.inventory_collection_name).to eq(:container_projects)
    end

    it "uses the by_name secondary index" do
      expect(lazy_ref.ref).to eq(:by_name)
    end
  end

  context "#lazy_find_node" do
    let(:lazy_ref) { parser.send(:lazy_find_node, "my-node") }
    it "defaults to container_nodes" do
      expect(lazy_ref.inventory_collection_name).to eq(:container_nodes)
    end

    it "uses the by_name secondary index" do
      expect(lazy_ref.ref).to eq(:by_name)
    end
  end
end
