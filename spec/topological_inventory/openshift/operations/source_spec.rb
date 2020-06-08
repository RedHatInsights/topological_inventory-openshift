require "sources-api-client"
require "topological_inventory/openshift/operations/source"

RSpec.describe(TopologicalInventory::Openshift::Operations::Source) do
  describe 'availability_check' do
    let(:host_url) { 'https://cloud.redhat.com' }
    let(:sources_api_path) { '/api/sources/v3.0' }
    let(:sources_internal_api_path) { '/internal/v1.0' }
    let(:sources_api_url) { "#{host_url}#{sources_api_path}" }

    let(:external_tenant) { '11001' }
    let(:identity) { {'x-rh-identity' => Base64.strict_encode64({'identity' => {'account_number' => external_tenant, 'user' => {'is_org_admin' => true}}}.to_json)} }
    let(:headers) { {'Content-Type' => 'application/json'}.merge(identity) }
    let(:source_id) { '123' }
    let(:endpoint_id) { '234' }
    let(:authentication_id) { '345' }
    let(:payload) do
      {
        'params' => {
          'source_id'       => source_id,
          'external_tenant' => external_tenant,
          'timestamp'       => Time.now.utc
        }
      }
    end

    let(:list_endpoints_response) { "{\"data\":[{\"default\":true,\"host\":\"10.0.0.1\",\"id\":\"#{endpoint_id}\",\"path\":\"/\",\"role\":\"ansible\",\"scheme\":\"https\",\"source_id\":\"#{source_id}\",\"tenant\":\"#{external_tenant}\"}]}" }
    let(:list_endpoint_authentications_response) { "{\"data\":[{\"authtype\":\"username_password\",\"id\":\"#{authentication_id}\",\"resource_id\":\"#{endpoint_id}\",\"resource_type\":\"Endpoint\",\"username\":\"admin\",\"tenant\":\"#{external_tenant}\"}]}" }
    let(:list_endpoint_authentications_response_empty) { "{\"data\":[]}" }
    let(:internal_api_authentication_response) { "{\"authtype\":\"username_password\",\"id\":\"#{authentication_id}\",\"resource_id\":\"#{endpoint_id}\",\"resource_type\":\"Endpoint\",\"username\":\"admin\",\"tenant\":\"#{external_tenant}\",\"password\":\"xxx\"}" }

    subject { described_class.new(payload["params"]) }

    context "when not checked recently" do
      before do
        allow(subject).to receive(:checked_recently?).and_return(false)
      end

      it "updates Source and Endpoint when available" do
        # GET
        stub_get(:endpoint, list_endpoints_response)
        stub_get(:authentication, list_endpoint_authentications_response)
        stub_get(:password, internal_api_authentication_response)

        # PATCH
        source_patch_body = {'availability_status' => described_class::STATUS_AVAILABLE, 'last_available_at' => subject.send(:check_time), 'last_checked_at' => subject.send(:check_time)}.to_json
        endpoint_patch_body = {'availability_status' => described_class::STATUS_AVAILABLE, 'availability_status_error' => '', 'last_available_at' => subject.send(:check_time), 'last_checked_at' => subject.send(:check_time)}.to_json

        stub_patch(:source, source_patch_body)
        stub_patch(:endpoint, endpoint_patch_body)

        # Check ---
        expect(subject).to receive(:connection_check).and_return([described_class::STATUS_AVAILABLE, nil])

        subject.availability_check

        assert_patch(:source, source_patch_body)
        assert_patch(:endpoint, endpoint_patch_body)
      end

      it "updates Source and Endpoint when unavailable" do
        # GET
        stub_get(:endpoint, list_endpoints_response)
        stub_get(:authentication, list_endpoint_authentications_response)
        stub_get(:password, internal_api_authentication_response)

        # PATCH
        connection_error_message = "Some connection error"
        source_patch_body        = {'availability_status' => described_class::STATUS_UNAVAILABLE, 'last_checked_at' => subject.send(:check_time)}.to_json
        endpoint_patch_body      = {'availability_status' => described_class::STATUS_UNAVAILABLE, 'availability_status_error' => connection_error_message, 'last_checked_at' => subject.send(:check_time)}.to_json

        stub_patch(:source, source_patch_body)
        stub_patch(:endpoint, endpoint_patch_body)

        # Check ---
        expect(subject).to receive(:connection_check).and_return([described_class::STATUS_UNAVAILABLE, connection_error_message])

        subject.availability_check

        assert_patch(:source, source_patch_body)
        assert_patch(:endpoint, endpoint_patch_body)
      end

      it "updates only Source to 'unavailable' status if Endpoint not found" do
        # GET
        stub_get(:endpoint, '')

        # PATCH
        source_patch_body = {'availability_status' => described_class::STATUS_UNAVAILABLE, 'last_checked_at' => subject.send(:check_time)}.to_json
        stub_patch(:source, source_patch_body)

        # Check
        api_client = subject.send(:api_client)
        expect(api_client).not_to receive(:update_endpoint)

        subject.availability_check

        assert_patch(:source, source_patch_body)
      end

      it "updates Source and Endpoint to 'unavailable' if Authentication not found" do
        # GET
        stub_get(:endpoint, list_endpoints_response)
        stub_get(:authentication, list_endpoint_authentications_response_empty)

        # PATCH
        source_patch_body   = {'availability_status' => described_class::STATUS_UNAVAILABLE, 'last_checked_at' => subject.send(:check_time)}.to_json
        endpoint_patch_body = {'availability_status' => described_class::STATUS_UNAVAILABLE, 'availability_status_error' => described_class::ERROR_MESSAGES[:authentication_not_found], 'last_checked_at' => subject.send(:check_time)}.to_json

        stub_patch(:source, source_patch_body)
        stub_patch(:endpoint, endpoint_patch_body)

        # Check
        expect(subject).not_to receive(:connection_check)
        subject.availability_check

        assert_patch(:source, source_patch_body)
        assert_patch(:endpoint, endpoint_patch_body)
      end
    end

    context "when checked recently" do
      before do
        allow(subject).to receive(:checked_recently?).and_return(true)
      end

      it "doesn't do connection check" do
        expect(subject).not_to receive(:connection_check)
        expect(WebMock).not_to have_requested(:patch, "#{sources_api_url}/sources/#{source_id}")
        expect(WebMock).not_to have_requested(:patch, "#{sources_api_url}/endpoints/#{endpoint_id}")

        subject.availability_check
      end
    end


    def stub_get(object_type, response)
      case object_type
      when :endpoint
        stub_request(:get, "#{sources_api_url}/sources/#{source_id}/endpoints")
          .with(:headers => headers)
          .to_return(:status => 200, :body => response, :headers => {})
      when :authentication
        stub_request(:get, "#{sources_api_url}/endpoints/#{endpoint_id}/authentications")
          .with(:headers => headers)
          .to_return(:status => 200, :body => response, :headers => {})
      when :password
        stub_request(:get, "#{host_url}#{sources_internal_api_path}/authentications/#{authentication_id}?expose_encrypted_attribute%5B%5D=password")
          .with(:headers => headers)
          .to_return(:status => 200, :body => response, :headers => {})
      end
    end

    def stub_patch(object_type, data)
      case object_type
      when :source
        stub_request(:patch, "#{sources_api_url}/sources/#{source_id}")
          .with(:body => data, :headers => headers)
          .to_return(:status => 200, :body => "", :headers => {})
      when :endpoint
        stub_request(:patch, "#{sources_api_url}/endpoints/#{endpoint_id}")
          .with(:body => data, :headers => headers)
          .to_return(:status => 200, :body => "", :headers => {})
      end
    end

    def assert_patch(object_type, data)
      case object_type
      when :source
        expect(WebMock).to have_requested(:patch, "#{sources_api_url}/sources/#{source_id}")
                             .with(:body => data, :headers => headers).once
      when :endpoint
        expect(WebMock).to have_requested(:patch, "#{sources_api_url}/endpoints/#{endpoint_id}")
                             .with(:body => data, :headers => headers).once
      end
    end
  end
end
