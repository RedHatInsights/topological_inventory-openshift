RSpec.describe TopologicalInventory::Openshift::CollectorsPool do
  let(:source1) { {:source => 'source1', :schema => 'http', :host => 'cloud.redhat.com', :port => 80} }
  let(:source2) { {:source => 'source2', :schema => 'https', :host => 'cloud.redhat.com', :port => 443} }
  let(:source3) { {:source => 'source3', :schema => 'xxx', :host => 'cloud.redhat.com', :port => 1234} }
  let(:source4) { {:source => 'source4', :schema => 'xxx', :host => 'cloud.redhat.com', :port => 1234} }
  let(:sources) { [source1, source2, source3] }

  before do
    @collector_pool = described_class.new(nil, nil)
    @collector = double
    allow(@collector_pool).to receive(:new_collector).and_return(@collector)
  end

  it "adds new collectors from settings" do
    allow(@collector).to receive(:collect!).and_return(nil)
    expect(@collector).to receive(:collect!).exactly(sources.size).times

    sources.each do |source|
      stub_settings_merge(:sources => ::Settings.sources.to_a + [source])

      @collector_pool.send(:add_new_collectors)

      saved_collectors = @collector_pool.send(:collectors)
      expect(saved_collectors[source[:source]]).to eq(@collector)
    end
    # Wait until threads finishes
    @collector_pool.send(:collector_threads).each_value(&:join)

    expect(@collector_pool.send(:collectors).keys).to eq(sources.collect { |s| s[:source] })
    expect(@collector_pool.send(:collector_threads).keys).to eq(sources.collect { |s| s[:source] })
  end

  it "removes existing collectors missing in settings" do
    mutex = Mutex.new
    cv = ConditionVariable.new
    i = 0

    allow(@collector).to receive(:collect!) { mutex.synchronize { i += 1; cv.wait(mutex) } }
    allow(@collector).to receive(:stop)

    expect(@collector).to receive(:stop).twice

    stub_settings_merge(:sources => sources)
    @collector_pool.send(:add_new_collectors)

    # Wait for all threads are collecting
    init = false
    until init
      mutex.synchronize { init = i == sources.size }
    end

    # Set new config
    new_sources = [source1]
    stub_settings_merge(:sources => new_sources)

    threads = @collector_pool.send(:collector_threads).dup
    @collector_pool.send(:remove_old_collectors)

    # Wait for all collecting is complete (rspec can throw error otherwise)
    mutex.synchronize { cv.broadcast }
    threads.each_value(&:join)

    expect(@collector_pool.send(:collectors).keys).to eq(new_sources.collect { |s| s[:source] })
    expect(@collector_pool.send(:collector_threads).keys).to eq(new_sources.collect { |s| s[:source] })
  end
end
