require 'yaml'

module OmfRc::Util::VirtualOpenflowSwitchTools
  include OmfRc::ResourceProxyDSL

  @config = YAML.load_file('/etc/omf_rc/ovs_proxy_conf.yaml')

  @ovs = (@config[:ovs].is_a? Hash) ? Hashie::Mash.new(@config[:ovs]) : @config[:ovs]

  # Internal function that returns a hash result of the json-request to the ovsdb-server or the ovs-switchd instances
  work :ovs_connection do |resource, target, arguments|
    stream = nil
    if target == "ovsdb-server"
      if @ovs.ovsdb_server_conn == "tcp"
        stream = TCPSocket.new(@ovs.ovsdb_server_host,
                               @ovs.ovsdb_server_port)
      elsif @ovs.ovsdb_server_conn == "unix"
        stream = UNIXSocket.new(@ovs.ovsdb_server_socket)
      end
    elsif target == "ovs-vswitchd"
      if @ovs.ovs_vswitchd_conn == "unix"
        file = File.new(@ovs.ovs_vswitchd_pid, "r")
        pid = file.gets.chomp
        file.close
        socket = @ovs.ovs_vswitchd_socket % [pid]
        stream = UNIXSocket.new(socket)
      end
    end
    stream.puts(arguments.to_json)
    string = stream.gets('{')
    counter = 1 # number of read '['
    while counter > 0
      char = stream.getc
      if char == '{'
        counter += 1
      elsif char == '}'
        counter -= 1
      end
      string += char
    end
    stream.close
    JSON.parse(string)
  end

  # Internal function that returns the ports of a specific switch
  work :ports do |resource|
    arguments = {
      "method" => "transact", 
      "params" => [ "Open_vSwitch", 
                    { "op" => "select", 
                      "table" => "Bridge", 
                      "where" => [["name", "==", resource.property.name]], 
                      "columns" => ["ports"]
                    },
                    { "op" => "select", 
                      "table" => "Port", 
                      "where" => [], 
                      "columns" => ["name", "_uuid"]
                    }
                  ],
      "id" => "ports"
    }
    result = resource.ovs_connection("ovsdb-server", arguments)["result"]
    uuid2name = Hash[result[1]["rows"].map {|hash_uuid_name| [hash_uuid_name["_uuid"][1], hash_uuid_name["name"]]}]
    uuids = result[0]["rows"][0]["ports"][1].map {|array_uuid| array_uuid[1]}
    uuids.map {|v| uuid2name[v]}
  end
end
