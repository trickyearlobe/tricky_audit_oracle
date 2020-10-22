#
# Cookbook:: tricky_audit_oracle
# Recipe:: default
#
# Copyright:: 2020, The Authors, All Rights Reserved.

include_recipe 'tricky_audit_oracle::ohai_setup'

# Loop through the Oracle database instances
node['oracle']['instances'].each do |sid, instance|
  # Scan an individual database instance
  ENV['ORACLE_HOME'] = instance['oracle_home']
  remote_audit_scan "Oracle database #{sid}" do
    node_name "#{sid}.#{node['fqdn']}"
    profiles [
      { source: 'chef', owner: 'admin', profile: 'cis-oracle-benchmark'},
      { source: 'chef', owner: 'admin', profile: 'example'},
    ]
    inputs(
      user: "tricky",
      password: "dicky",
      host: "localhost",
      service: instance['service'],
      oracle_home: instance['oracle_home'],
      sqlplus_bin: instance['oracle_cli'],
      oracle_host_checks: true,
    )
  end
end