# This resourse is related with an ovsdb-server (interface of an OVSDB database) and behaves as a proxy between experimenter and this.
#
module OmfRc::ResourceProxy::OvsFactory
  include OmfRc::ResourceProxyDSL

  @config = YAML.load_file('/etc/omf_rc/ovs_conf.yaml')

  @ovs = @config['ovs']

  $UUID = ""

  register_proxy :ovs_proxy_factory

  utility :virtual_openflow_switch_tools


  # Checks if the created child is an :ovs_proxy resource and passes the connection arguments
  hook :before_create do |resource, type, opts|
    if type.to_sym != :ovs_proxy
      raise "This resource doesn't create resources of type "+type
    end
    arguments = {
      "method" => "transact",
      "params" => [ "Open_vSwitch",
                    { "op" => "insert",
                      "table" => "Interface",
                      "row" => {"name" => opts[:name], "type" => "internal"},
                      "uuid-name" => "new_interface"
                    },
                    { "op" => "insert",
                      "table" => "Port",
                      "row" => {"name" => opts[:name], "interfaces" => ["named-uuid", "new_interface"]},
                      "uuid-name" => "new_port"
                    },
                    { "op" => "insert",
                      "table" => "Controller",
                      "row" => {"target" => "tcp:127.0.0.1:6633"},
                      "uuid-name" => "new_controller"
                    },
                    { "op" => "insert",
                      "table" => "Bridge",
                      "row" => {"name" => opts[:name], "ports" => ["named-uuid", "new_port"], "datapath_type" => "netdev", "fail_mode" => "secure",
                                "controller" => ["named-uuid", "new_controller"]},
                      "uuid-name" => "new_bridge"
                    },
                    { "op" => "mutate",
                      "table" => "Open_vSwitch",
                      "where" => [],
                      "mutations" => [["bridges", "insert", ["set", [["named-uuid", "new_bridge"]]]]]
                    }
                  ],
      "id" => "add-switch"
    }
    result = resource.ovs_connection("ovsdb-server", arguments)["result"]
    raise "The requested switch already existed in ovsdb-server or other problem" if result.to_s.include?("error")
    opts[:property] ||= Hashie::Mash.new
    opts[:property].provider = ">> #{resource.uid}"
    opts[:property].ovs_connection_args = @ovs
    opts[:property].uuid = result[2]["uuid"][1]
    $UUID = result[2]["uuid"][1]
  end

  # A new resource uses the default connection arguments (ip adress, port, socket, etc) to connect with a ovsdb-server instance
  hook :before_ready do |resource|
    @ovs = OVS_CONNECTION_DEFAULTS
  end


  # Configures the ovsdb-server connection arguments (ip adress, port, socket, etc)
  configure :ovs_connection do |resource, ovs_connection_args|
    raise "Connection with a new ovsdb-server instance is not allowed if there exist created switches" if !resource.children.empty?
    @ovs.update(ovs_connection_args)
  end


  # Returns the ovsdb-server connection arguments (ip adress, port, socket, etc)
  request :ovs_connection do |resource|
    @ovs
  end

  # Returns a list of virtual openflow switches, that correspond to the ovsdb-server bridges.
  request :switches do |resource|
    arguments = {
      "method" => "transact", 
      "params" => [ "Open_vSwitch", 
                    { "op" => "select", 
                      "table" => "Bridge", 
                      "where" => [], 
                      "columns" => ["name"]
                    }
                  ],
      "id" => "switches"
    }
    result = resource.ovs_connection("ovsdb-server", arguments)["result"]
    result[0]["rows"].map {|hash_name| hash_name["name"]}
  end
end
