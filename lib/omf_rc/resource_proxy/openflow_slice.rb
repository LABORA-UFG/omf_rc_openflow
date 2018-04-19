# This resource is created from the parent :flowvisor_proxy_factory resource.
# It is related with a slice of a flowvisor instance, and behaves as a proxy between experimenter and the actual flowvisor slice.
#
require 'yaml'

module OmfRc::ResourceProxy::OpenflowSlice
  include OmfRc::ResourceProxyDSL

  @config = YAML.load_file('/etc/omf_rc/flowvisor_proxy_conf.yaml')

  register_proxy :openflow_slice, :create_by => :flowvisor

  utility :openflow_slice_tools

  property :name, :default => nil
  property :flowvisor_connection_args

  # Before release, the related flowvisor instance should also remove the corresponding slice
  hook :before_release do |resource|
    resource.flowvisor_connection.call("api.deleteSlice", resource.property.name)
  end


  # Configures the slice password
  configure :passwd do |resource, passwd|
    resource.flowvisor_connection.call("api.changePasswd", resource.property.name, passwd.to_s)
    passwd.to_s
  end

  # Configures the slice parameters
  [:contact_email, :drop_policy, :controller_hostname, :controller_port].each do |configure_sym|
    configure configure_sym do |resource, value|
      resource.flowvisor_connection.call("api.changeSlice", resource.property.name, configure_sym.to_s, value.to_s)
      value.to_s
    end
  end

  # Adds/removes a flow to this slice, specified by device, port, etc.
  configure :flows do |resource, array_parameters|
    array_parameters = [array_parameters] if !array_parameters.kind_of?(Array)

    array_parameters.each do |parameters|
      resource.flowvisor_connection.call("api.changeFlowSpace", resource.transformed_parameters(parameters))
    end
    resource.flows
  end


  # Returns a hash table with the name of this slice, its controller (ip and port) and other related information
  request :info do |resource|
    result = resource.flowvisor_connection.call("api.getSliceInfo", resource.property.name)
    result[:name] = resource.property.name
    result
  end

  # Returns a string with statistics about the use of this slice
  request :stats do |resource|
    resource.flowvisor_connection.call("api.getSliceStats", resource.property.name)
  end

end
