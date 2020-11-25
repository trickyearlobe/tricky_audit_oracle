#
# Cookbook:: tricky_audit_oracle
# Recipe:: default
#
# Copyright:: 2020, The Authors, All Rights Reserved.

include_recipe 'tricky_audit_oracle::ohai_setup'

# Loop through the Oracle database instances
node['oracle']['instances'].each do |sid, instance|
  ENV['ORACLE_HOME'] = instance['oracle_home']
  ENV['ORACLE_SID'] = sid

  # Scan an individual database instance
  remote_audit_scan "Oracle database #{sid}" do
    node_name "#{sid}.#{node['fqdn']}"
    profiles [
      { source: 'chef', owner: 'admin', profile: 'cis-oracle-benchmark'},
      { source: 'chef', owner: 'admin', profile: 'example'},
    ]
    inputs(
      #### Doing it this way with service names needs creds for a user with SYSDBA privs
      # user: "michael",
      # password: "mouse",
      # as_db_role: "SYSDBA",
      # service: instance['services'].first,
      # sqlplus_bin: instance['oracle_cli'],
      # oracle_host_checks: true,

      #### This works for a local SID with no creds, but we currently have to ship a monkey-patched
      #### version of oracledb_session in this cookbook to overcome the following Inspec bugs:-
      #### * Inspec shipped with CC16 requires :as_su_user instead of :su_user but the Oracle CIS profile can only pass :su_user
      #### * Inspec (version?) doesn't correctly escape $ when running as the :su_user causing queries on v$parameter to fail
      #### * Sometimes query failures are masked if they use .row or .column properties causing false passes
      su_user: instance['user'],
      as_db_role: "SYSDBA",
      service: sid,
      sqlplus_bin: instance['oracle_cli'],
      oracle_host_checks: true,
    )
  end
end