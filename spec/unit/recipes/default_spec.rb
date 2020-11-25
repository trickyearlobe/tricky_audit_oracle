#
# Cookbook:: tricky_audit_oracle
# Spec:: default
#
# Copyright:: 2020, The Authors, All Rights Reserved.

require 'spec_helper'

describe 'tricky_audit_oracle::default' do
  context 'When all attributes are default, it' do
    platform 'centos', '8'

    it 'monkey patches oracledb_session' do
      expect(::Inspec::Resources::OracledbSession.instance_methods).not_to include :escape_sql
    end

  end
end
