# This resource is created from the parent :ovs_proxy_factory resource.
# It is related with a bridge of an ovsdb-server instance, and behaves as a proxy between experimenter and the actual ovsdb-server bridge.
#
require 'yaml'

module OmfRc::ResourceProxy::Ovs
  include OmfRc::ResourceProxyDSL

  @config = YAML.load_file('/etc/omf_rc/ovs_proxy_conf.yaml')

  @ovs = (@config[:ovs].is_a? Hash) ? Hashie::Mash.new(@config[:ovs]) : @config[:ovs]

  register_proxy :ovs_proxy, :create_by => :ovs_proxy_factory

  utility :virtual_openflow_switch_tools

  property :name, :default => nil


  # Before release, the related ovsdb-server instance should also remove the corresponding switch
  hook :before_release do |resource|
    resource.property.uuid = $UUID
    info "\n\n------------------------------#{resource.property.uuid}\n\n"
    arguments = {
      "method" => "transact",
      "params" => [ "Open_vSwitch",
                    { "op" => "mutate",
                      "table" => "Open_vSwitch",
                      "where" => [],
                      "mutations" => [["bridges", "delete", ["set", [["uuid", resource.property.uuid]]]]]
                    },
                    { "op" => "delete",
                      "table" => "Bridge",
                      "where" => [["name", "==", resource.property.name]],
                    },
                    { "op" => "delete",
                      "table" => "Port",
                      "where" => [["name", "==", resource.property.name]]
                    },
                    { "op" => "delete",
                      "table" => "Interface",
                      "where" => [["name", "==", resource.property.name]]
                    }
                  ],
      "id" => "remove-switch"
    }
    result = resource.ovs_connection("ovsdb-server", arguments)["result"]
    #raise "The removal of the switch ports faced a problem: #{result}" if result.to_s.include?('error')
  end


  # Add/remove port
  configure :ports do |resource, array_parameters|
    array_parameters = [array_parameters] if !array_parameters.kind_of?(Array)
    array_parameters.each do |parameters|
      arguments = nil
      if parameters.operation == "add"
        arguments = {
          "method" => "transact",
          "params" => [ "Open_vSwitch",
                        { "op" => "insert",
                          "table" => "Interface",
                          "row" => {"name" => parameters.name},
                          "uuid-name" => "new_interface"
                        },
                        { "op" => "insert",
                          "table" => "Port",
                          "row" => {"name" => parameters.name, "interfaces" => ["named-uuid", "new_interface"]},
                          "uuid-name" => "new_port"
                        },
                        { "op" => "mutate",
                          "table" => "Bridge",
                          "where" => [["name", "==", resource.property.name]],
                          "mutations" => [["ports", "insert", ["set", [["named-uuid", "new_port"]]]]]
                        }
                      ],
          "id" => "add-port"
        }
      elsif parameters.operation == "remove" # TODO: It is not filled
      end
      result = resource.ovs_connection("ovsdb-server", arguments)["result"]
      raise "The configuration of the switch ports faced a problem" if result[3]
    end
    resource.ports
  end

  # Request port information (XXX: very restrictive, just to support our case)
  request :port do |resource, parameters|
    arguments = {
      "method" => parameters.information,
      "params" => [parameters.name],
      "id" => "port-info"
    }
    resource.ovs_connection("ovs-vswitchd", arguments)["result"]
  end

  # Configure port (XXX: very restrictive, just to support our case)
  configure :port do |resource, parameters|
    arguments = {
      "method" => "transact",
      "params" => [ "Open_vSwitch",
                    { "op" => "mutate",
                      "table" => "Interface",
                      "where" => [["name", "==", parameters.name]],
                      "mutations" => [["options", "insert", ["map", 
                         [["remote_ip", parameters.remote_ip], ["remote_port", parameters.remote_port.to_s]]]]]
                    }
                  ],
      "id" => "configure-port"
    }
    resource.ovs_connection("ovsdb-server", arguments)["result"]
  end

  # Request tunnel port numbers of this switch
  request :tunnel_port_numbers do |resource|
    ports = resource.ports("tunnel")
    port_num = ports.map do |port|
      arguments = {
        "method" => "netdev-tunnel/get-port",
        "params" => [port],
        "id" => "port-number"
      }
      [port, resource.ovs_connection("ovs-vswitchd", arguments)["result"]]
    end
    Hashie::Mash.new(Hash[port_num])
  end

  #configure :name do |resource, parameters|
  #  :name = parameters.name
  #end

  # Configure tunnel ports
  configure :tunnel_port do |resource, parameters|
    arguments = {
      "method" => "transact",
      "params" => [ "Open_vSwitch",
                    { "op" => "mutate",
                      "table" => "Interface",
                      "where" => [["name", "==", parameters.name]],
                      "mutations" => [["options", "insert", ["map", 
                         [["remote_ip", parameters.remote_ip], ["remote_port", parameters.remote_port.to_s]]]]]
                    }
                  ],
      "id" => "configure-tunnel-port"
    }
    resource.ovs_connection("ovsdb-server", arguments)["result"]
  end
end
