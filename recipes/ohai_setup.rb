#
# Cookbook:: tricky_audit_oracle
# Recipe:: ohai_setup
#
# Copyright:: 2020, The Authors, All Rights Reserved.

ohai 'oracle' do
  plugin 'oracle'
  action :nothing
end

directory File.join(Chef::Config['config_dir'], 'ohai', 'plugins') do
  recursive true
end.run_action(:create)

cookbook_file File.join(Chef::Config['config_dir'], 'ohai', 'plugins', 'ohai_oracle.rb') do
  notifies :reload, 'ohai[oracle]', :immediately
end.run_action(:create)