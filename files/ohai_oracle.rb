require 'mixlib/shellout'

Ohai.plugin(:Oracle) do
  provides 'oracle'

  collect_data(:default) do
    oracle Mash.new

    # Look for running instances of ora_pmon_*
    oracle['instances'] = `ps -ef`.lines.map do |l|
      l.split
    end.filter do |l|
      l[7] =~ /^ora_pmon_/
    end.map do |l|
      { "user"=>l[0], "pid"=>l[1], "parent"=>l[2], "cgroup"=>l[3], "start_time"=>l[4], "tty"=>l[5], "exec_time"=>l[6], "cmd"=>l[7], "params"=>l[8..].join(' ')}
    end.map do |l|
      env = File.read("/proc/#{l["pid"]}/environ").split("\u0000").map do |e|
        [e.split('=')[0], e.split('=')[1..].join('=')]
      end.to_h
      l['sid']         = env['ORACLE_SID']
      l['oracle_base'] = env['ORACLE_BASE']
      l['oracle_home'] = env['ORACLE_HOME']
      l['oracle_cli']  = env['_']
      [ l['sid'], l ]
    end.to_h

    # Try to get the service names using a local SID connection with SYSDBA role
    oracle['instances'].each do |sid, instance|
      if File.exist? instance['oracle_cli']
        query=['connect / as SYSDBA', 'show parameter service', 'exit'].join("\n")
        env={"ORACLE_HOME" => instance['oracle_home'], "ORACLE_SID" => sid}
        cmd = Mixlib::ShellOut.new(
          instance['oracle_cli'], "-S", "/nolog",
          user:instance['user'],
          input:query,
          environment:env
        )
        cmd.run_command
        oracle['instances'][sid]['service'] = (cmd.stdout || cmd.stderr).lines.map do |l|
          l.split
        end.filter do |l|
          l[0] == 'service_names'
        end.map do |l|
          l[2]
        end.first
      end
    end
  end
end