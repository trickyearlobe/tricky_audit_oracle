# Pull in core Inspec
require 'inspec'
# Make sure oracledb_session can't get loaded again somewhere else
require "inspec/resources/oracledb_session"

# Whack the original completely to remove unexpected methods in case its not the version we expect
::Inspec::Resources.send(:remove_const, :OracledbSession)

module Inspec::Resources
  class OracledbSession < Inspec.resource(1)
    name "oracledb_session"
    supports platform: "unix"
    supports platform: "windows"
    desc "Use the oracledb_session InSpec resource to test commands against an Oracle database"
    example <<~EXAMPLE
      sql = oracledb_session(user: 'my_user', pass: 'password')
      describe sql.query(\"SELECT UPPER(VALUE) AS VALUE FROM V$PARAMETER WHERE UPPER(NAME)='AUDIT_SYS_OPERATIONS'\").row(0).column('value') do
        its('value') { should eq 'TRUE' }
      end
    EXAMPLE

    attr_reader :bin, :db_role, :host, :password, :port, :service,
                :su_user, :user

    def initialize(opts = {})
      @user = opts[:user]
      @password = opts[:password] || opts[:pass]
      if opts[:pass]
        Inspec.deprecate(:oracledb_session_pass_option, "The oracledb_session `pass` option is deprecated. Please use `password`.")
      end

      @bin = "sqlplus"
      @host = opts[:host] || "localhost"
      @port = opts[:port] || "1521"
      @service = opts[:service]
      @su_user = opts[:as_os_user] || opts[:su_user]
      @db_role = opts[:as_db_role]
      @sqlcl_bin = opts[:sqlcl_bin] || nil
      @sqlplus_bin = opts[:sqlplus_bin] || "sqlplus"
      skip_resource "Option 'as_os_user' not available in Windows" if inspec.os.windows? && su_user
      fail_resource "Can't run Oracle checks without authentication" unless su_user && (user || password)
      fail_resource "You must provide a service name for the session" unless service
    end

    def query(sql)
      if @sqlcl_bin && inspec.command(@sqlcl_bin).exist?
        @bin = @sqlcl_bin
        format_options = "set sqlformat csv\nSET FEEDBACK OFF"
      else
        @bin = "#{@sqlplus_bin} -S"
        format_options = "SET MARKUP CSV ON\nSET PAGESIZE 32000\nSET FEEDBACK OFF"
      end

      command = command_builder(format_options, sql)
      inspec_cmd = inspec.command(command)
      # This might feel a bit aggressive but we use raise here because fail_resource doesn't
      # bubble up to the top and give an obvious clean reason for a failure. In some cases failures
      # are even masked when using .row or .column properties of result sets.
      raise "Sad times 😞\nAn error occured executing an Oracle query\n\n#{inspec_cmd.stdout}" if
        ( inspec_cmd.stdout =~ /^ORA-\d+:/ ) || # Oracle error code
        ( inspec_cmd.stdout =~ /^SP2-\d+:/ ) || # SQL*Plus error code
        ( inspec_cmd.stdout =~ /^CPY-\d+:/ )    # COPY error code
      DatabaseHelper::SQLQueryResult.new(inspec_cmd, parse_csv_result(inspec_cmd.stdout))
    end

    def to_s
      "Oracle Session"
    end

    private

    # 3 commands
    # regular user password
    # using a db_role
    # su, using a db_role
    def command_builder(format_options, query)
      verified_query = verify_query(query)
      sql_prefix, sql_postfix = "", ""
      if inspec.os.windows?
        sql_prefix = %{@'\n#{format_options}\n#{verified_query}\nEXIT\n'@ | }
      else
        sql_postfix = %{ <<'EOC'\n#{format_options}\n#{verified_query}\nEXIT\nEOC}
      end

      if @db_role.nil?
        %{#{sql_prefix}#{bin} "#{user}"/"#{password}"@#{host}:#{port}/#{@service}#{sql_postfix}}
      elsif @su_user.nil?
        %{#{sql_prefix}#{bin} "#{user}"/"#{password}"@#{host}:#{port}/#{@service} as #{@db_role}#{sql_postfix}}
      else
        %{su - #{@su_user} -c "env ORACLE_SID=#{@service} #{@bin} / as #{@db_role}#{escape_sql(sql_postfix)}"}
      end
    end

    def verify_query(query)
      query += ";" unless query.strip.end_with?(";")
      query
    end

    def parse_csv_result(stdout)
      output = stdout.sub(/\r/, "").strip
      converter = ->(header) { header.downcase }
      CSV.parse(output, headers: true, header_converters: converter).map { |row| Hashie::Mash.new(row.to_h) }
    end

    def escape_sql(sql)
      sql.gsub('$','\$')
    end

  end
end