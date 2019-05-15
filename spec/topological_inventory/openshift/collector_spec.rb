RSpec.describe TopologicalInventory::Openshift::Collector do
  let(:collector) do
    collector = described_class.new(
      source,
      "mock_openshift.redhat.com",
      "8443",
      "secret",
      double("ApplicationMetrics", :record_error => nil)
    )

    allow(collector).to receive(:ingress_api_client).and_return(client)
    allow(collector).to receive(:logger).and_return(logger)

    collector
  end

  let(:parser) { TopologicalInventory::Openshift::Parser.new(:openshift_host => "localhost") }

  let(:source)  { "source_uid" }
  let(:client)  { double }
  let(:logger)  { double }
  let(:refresh_state_uuid) { SecureRandom.uuid }
  let(:refresh_state_part_uuid) { SecureRandom.uuid }
  # Current limit is 1 MB, so that is max 1000 entities of the current size, if the limit is 2MB change this to 2
  let(:multiplier) { 1 }

  context "#save_inventory" do
    it "does nothing with empty collections" do
      parts = collector.send(:save_inventory, [], refresh_state_uuid, refresh_state_part_uuid)

      expect(parts).to eq 0
    end

    it "saves 1 part if it fits" do
      (multiplier * 1000).times { parser.collections.container_groups.build(:source_ref => "a" * 981) }

      expect(inventory_size(parser.collections.values)).to eq(999242)

      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times
      parts = collector.send(:save_inventory, parser.collections.values, refresh_state_uuid, refresh_state_part_uuid)
      expect(parts).to eq 1
    end

    it "saves 2 parts if over limit with 1 collection" do
      (multiplier * 2000).times { parser.collections.container_groups.build(:source_ref => "a" * 981) }

      expect(inventory_size(parser.collections.values)).to eq(1998242)

      expect(client).to receive(:save_inventory_with_http_info).exactly(2).times
      parts = collector.send(:save_inventory, parser.collections.values, refresh_state_uuid, refresh_state_part_uuid)
      expect(parts).to eq 2
    end

    it "saves 2 parts if over limit with 2 collections" do
      (multiplier * 1000).times { parser.collections.container_groups.build(:source_ref => "a" * 981) }
      (multiplier * 1000).times { parser.collections.container_nodes.build(:source_ref => "a" * 981) }

      expect(inventory_size(parser.collections.values)).to eq(1998278)

      expect(client).to receive(:save_inventory_with_http_info).exactly(2).times
      parts = collector.send(:save_inventory, parser.collections.values, refresh_state_uuid, refresh_state_part_uuid)
      expect(parts).to eq 2
    end

    it "saves many parts" do
      (multiplier * 1500).times { parser.collections.container_groups.build(:source_ref => "a" * 981) }
      (multiplier * 2000).times { parser.collections.container_nodes.build(:source_ref => "a" * 981) }

      expect(client).to receive(:save_inventory_with_http_info).exactly(4).times
      parts = collector.send(:save_inventory, parser.collections.values, refresh_state_uuid, refresh_state_part_uuid)
      expect(parts).to eq 4
    end

    it 'raises exception when entity to save is too big' do
      parser.collections.container_groups.build(:source_ref => "a" * 1_000_000 * multiplier)

      expect(inventory_size(parser.collections.values)).to eq(1000260)
      # in this case, we first save empty inventory, then the size check fails saving the rest of data
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      expect { collector.send(:save_inventory, parser.collections.values, refresh_state_uuid, refresh_state_part_uuid) }.to(
        raise_error(TopologicalInventoryIngressApiClient::SaveInventory::Exception::EntityTooLarge)
      )
    end

    it 'raises exception when entity of second collection is too big' do
      (multiplier * 1000).times { parser.collections.container_groups.build(:source_ref => "a" * 981) }
      parser.collections.container_nodes.build(:source_ref => "a" * 1_000_000 * multiplier)

      expect(inventory_size(parser.collections.values)).to eq(1999296)
      # We save the first collection then it fails on saving the second collection
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      expect { collector.send(:save_inventory, parser.collections.values, refresh_state_uuid, refresh_state_part_uuid) }.to(
        raise_error(TopologicalInventoryIngressApiClient::SaveInventory::Exception::EntityTooLarge)
      )
    end

    it 'raises exception when entity of second collection is too big then continues with smaller' do
      (multiplier * 1000).times { parser.collections.container_groups.build(:source_ref => "a" * 981) }
      parser.collections.container_nodes.build(:source_ref => "a" * 1_000_000 * multiplier)
      (multiplier * 1000).times { parser.collections.container_nodes.build(:source_ref => "a" * 981) }

      expect(inventory_size(parser.collections.values)).to eq(2998296)
      # We save the first collection then it fails on saving the second collection
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      expect { collector.send(:save_inventory, parser.collections.values, refresh_state_uuid, refresh_state_part_uuid) }.to(
        raise_error(TopologicalInventoryIngressApiClient::SaveInventory::Exception::EntityTooLarge)
      )
    end
  end

  context "#sweep_inventory" do
    it "with nil total parts" do
      expect(client).to receive(:save_inventory_with_http_info).exactly(0).times

      collector.send(:sweep_inventory, refresh_state_uuid, nil, [])
    end

    it "with empty scope " do
      expect(client).to receive(:save_inventory_with_http_info).exactly(0).times

      collector.send(:sweep_inventory, refresh_state_uuid, 1, [])
    end

    it "with normal scope " do
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      collector.send(:sweep_inventory, refresh_state_uuid, 1, [:container_groups])
    end

    it "with normal targeted scope " do
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      collector.send(:sweep_inventory, refresh_state_uuid, 1, {:container_groups => [{:source_ref => "a"}]})
    end

    it "fails with scope entity too large " do
      expect(client).to receive(:save_inventory_with_http_info).exactly(0).times

      sweep_scope = {:container_groups => [{:source_ref => "a" * 1_000_002 * multiplier}]}

      expect { collector.send(:sweep_inventory, refresh_state_uuid, 1, sweep_scope) }.to(
        raise_error(TopologicalInventoryIngressApiClient::SaveInventory::Exception::EntityTooLarge)
      )
    end

    it "fails when scope is too big " do
      # We should have also sweep scope chunking, that is if we'll do big targeted refresh and sweeping
      expect(client).to receive(:save_inventory_with_http_info).exactly(0).times

      sweep_scope = {:container_groups => (0..1001 * multiplier).map { {:source_ref => "a" * 1_000} } }

      expect { collector.send(:sweep_inventory, refresh_state_uuid, 1, sweep_scope) }.to(
        raise_error(TopologicalInventoryIngressApiClient::SaveInventory::Exception::EntityTooLarge)
      )
    end
  end

  def build_inventory(collections)
    TopologicalInventoryIngressApiClient::Inventory.new(
      :name                    => "OCP",
      :schema                  => TopologicalInventoryIngressApiClient::Schema.new(:name => "Default"),
      :source                  => source,
      :collections             => collections,
      :refresh_state_uuid      => refresh_state_uuid,
      :refresh_state_part_uuid => refresh_state_part_uuid,
    )
  end

  def inventory_size(collections)
    JSON.generate(build_inventory(collections).to_hash).size
  end
end
