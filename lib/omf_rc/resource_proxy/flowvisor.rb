# This resourse is related with a flowvisor instance and behaves as a proxy between experimenter and flowvisor.
#
require 'yaml'
require 'securerandom'

module OmfRc::ResourceProxy::Flowvisor
  include OmfRc::ResourceProxyDSL

  @config = YAML.load_file('/etc/omf_rc/flowvisor_proxy_conf.yaml')

  @flowvisor = (@config[:flowvisor].is_a? Hash) ? Hashie::Mash.new(@config[:flowvisor]) : @config[:flowvisor]

  register_proxy :flowvisor

  utility :openflow_slice_tools
  property :flowvisor_connection_args, :default => @flowvisor

  # Checks if the created child is an :openflow_slice resource and passes the connection arguments that are essential for the connection with flowvisor instance
  hook :before_create do |resource, type, opts|
    if type.to_sym != :openflow_slice
      raise "This resource doesn't create resources of type "+type
    elsif opts[:name] == nil
      raise "The created slice must be configured with a name"
    elsif opts[:controller_url] == nil
      raise "You must supply the controller URL for this slice"
    end
    resource.property.slice_default_configuration = @config

    slices = resource.flowvisor_connection.call("api.listSlices")

    debug "Existing slices: #{slices}"

    unless slices.include? opts[:name].to_s
      #TODO verify slice name to remove dot character or raise an exception if the name has dots
      resource.flowvisor_connection.call("api.createSlice", opts[:name].to_s,
                                         @config[:slice][:passwd], opts[:controller_url].to_s,
                                         @config[:slice][:email])
    end

    opts[:uid] = opts[:name].to_s
    if @config[:pubsub][:federate] and @config[:pubsub][:domain]
      opts[:uid] = "fed-#{@config[:pubsub][:domain]}-#{opts[:uid]}"
    end
    opts[:property] ||= Hashie::Mash.new
    opts[:property].provider = ">> #{resource.uid}"
    opts[:flowvisor_connection_args] = @flowvisor
  end

  # A new resource uses the default connection arguments (ip adress, port, etc) to connect with a flowvisor instance
  hook :before_ready do |resource|
    resource.property.flowvisor_connection_args = @flowvisor
  end


  # Configures the flowvisor connection arguments (ip adress, port, etc)
  configure :flowvisor_connection do |resource, flowvisor_connection_args|
    raise "Connection with a new flowvisor instance is not allowed if there exist created slices" if !resource.children.empty?
    resource.property.flowvisor_connection_args.update(flowvisor_connection_args)
  end


  # Returns the flowvisor connection arguments (ip adress, port, etc)
  request :flowvisor_connection do |resource|
    resource.property.flowvisor_connection_args
  end

  # Returns a list of the existed slices or the connected devices
  {:slices => "listSlices", :devices => "listDevices"}.each do |request_sym, handler_name|
    request request_sym do |resource|
      resource.flowvisor_connection.call("api.#{handler_name}")
    end
  end

  # Returns information or statistics for a device specified by the given id
  {:device_info => "getDeviceInfo", :device_stats => "getSwitchStats"}.each do |request_sym, handler_name|
    request request_sym do |resource, device|
      resource.flowvisor_connection.call("api.#{handler_name}", device.to_s) unless device.to_s.empty?
    end
  end

  # Returns the links
  request :links do |resource|
    resource.flowvisor_connection.call("api.getLinks")
  end

end
