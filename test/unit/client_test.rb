require 'test_helper'

class Elasticsearch::Transport::ClientTest < Test::Unit::TestCase

  class DummyTransport
    def initialize(*); end
  end

  context "Client" do
    setup do
      Elasticsearch::Transport::Client::DEFAULT_TRANSPORT_CLASS.any_instance.stubs(:__build_connections)
      @client = Elasticsearch::Transport::Client.new
    end

    should "be aliased as Elasticsearch::Client" do
      assert_nothing_raised do
        assert_instance_of(Elasticsearch::Transport::Client, Elasticsearch::Client.new)
      end
    end

    should "have default transport" do
      assert_instance_of Elasticsearch::Transport::Client::DEFAULT_TRANSPORT_CLASS, @client.transport
    end

    should "instantiate custom transport class" do
      client = Elasticsearch::Transport::Client.new :transport_class => DummyTransport
      assert_instance_of DummyTransport, client.transport
    end

    should "take custom transport instance" do
      client = Elasticsearch::Transport::Client.new :transport => DummyTransport.new
      assert_instance_of DummyTransport, client.transport
    end

    should "delegate performing requests to transport" do
      assert_respond_to @client, :perform_request
      @client.transport.expects(:perform_request)
      @client.perform_request 'GET', '/'
    end

    should "have default logger for transport" do
      client = Elasticsearch::Transport::Client.new :log => true
      assert_respond_to client.transport.logger, :info
    end

    should "have default tracer for transport" do
      client = Elasticsearch::Transport::Client.new :trace => true
      assert_respond_to client.transport.tracer, :info
    end

    context "when passed hosts" do
      should "have localhost by default" do
        c = Elasticsearch::Transport::Client.new
        assert_equal 'localhost', c.transport.hosts.first[:host]
      end

      should "take :hosts, :host or :url" do
        c1 = Elasticsearch::Transport::Client.new :hosts => ['foobar']
        c2 = Elasticsearch::Transport::Client.new :host  => 'foobar'
        c3 = Elasticsearch::Transport::Client.new :url   => 'foobar'
        assert_equal 'foobar', c1.transport.hosts.first[:host]
        assert_equal 'foobar', c2.transport.hosts.first[:host]
        assert_equal 'foobar', c3.transport.hosts.first[:host]
      end
    end

    context "extracting hosts" do
      should "handle defaults" do
        assert_equal [ {:host => 'localhost', :port => nil} ], @client.__extract_hosts
      end

      should "extract from string" do
        assert_equal [ {:host => 'myhost', :port => nil} ], @client.__extract_hosts( 'myhost' )
      end

      should "extract from array" do
        assert_equal [ {:host => 'myhost', :port => nil} ], @client.__extract_hosts( ['myhost'] )
      end

      should "extract from array with multiple hosts" do
        assert_equal [ {:host => 'host1', :port => nil}, {:host => 'host2', :port => nil} ],
                     @client.__extract_hosts( ['host1', 'host2'] )
      end

      should "extract from array with ports" do
        assert_equal [ {:host => 'host1', :port => '1000'}, {:host => 'host2', :port => '2000'} ],
                     @client.__extract_hosts( ['host1:1000', 'host2:2000'] )
      end

      should "pass Hashes over" do
        assert_equal [ {:host => 'myhost', :port => '1000'} ],
                     @client.__extract_hosts( [{:host => 'myhost', :port => '1000'}] )
      end

      should "raise error for incompatible argument" do
        assert_raise ArgumentError do
          @client.__extract_hosts 123
        end
      end

      should "randomize hosts" do
        hosts = [ {:host => 'host1'}, {:host => 'host2'}, {:host => 'host3'}, {:host => 'host4'}, {:host => 'host5'}]
        assert_not_equal     hosts, @client.__extract_hosts(hosts, :randomize_hosts => true)
        assert_same_elements hosts, @client.__extract_hosts(hosts, :randomize_hosts => true)
      end
    end

  end
end
