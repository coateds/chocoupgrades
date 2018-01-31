# To learn more about Custom Resources, see https://docs.chef.io/custom_resources.html
# Bump

property :dir, String
property :pkg, String
property :ver, String

# Install the pkg with version ver
# Notify the ruby block that calls the write log function
action :install do
  chocolatey_package new_resource.pkg do
    action :install
    version new_resource.ver.to_s
    notifies :run, 'ruby_block[LogInstallPkgMsg]', :immediate
  end

  # pass a customized message to the writelog function
  ruby_block 'LogInstallPkgMsg' do
    block do
      writelog "Installed #{new_resource.pkg}, Version #{new_resource.ver}"
    end
    action :nothing
  end
end

# Uninstall the pkg
# uninstall has be deprecated for chocolatey_package
# use remove instead
action :uninstall do
  chocolatey_package new_resource.pkg do
    action :remove
    notifies :run, 'ruby_block[LogUninstallPkgMsg]', :immediate
  end

  # pass a customized message to the writelog function
  ruby_block 'LogUninstallPkgMsg' do
    block do
      writelog "Uninstalled #{new_resource.pkg}"
    end
    action :nothing
  end
end

# upgrade the pkg
action :upgrade do
  chocolatey_package new_resource.pkg do
    action :upgrade
    notifies :run, 'ruby_block[LogUpgradePkgMsg]', :immediate
  end

  # pass a customized message to the writelog function
  ruby_block 'LogUpgradePkgMsg' do
    block do
      writelog "Upgraded #{new_resource.pkg}"
    end
    action :nothing
  end
end

# Used for testing the concept
action :mkdir do
  directory new_resource.dir do
    action :create
    notifies :run, 'ruby_block[LogDirMsg]', :immediate
  end

  ruby_block 'LogDirMsg' do
    block do
      writelog "Created #{new_resource.dir}"
    end
    action :nothing
  end
end

# Used for testing the concept
action :rmdir do
  directory new_resource.dir do
    action :delete
    notifies :run, 'ruby_block[LogRmDirMsg]', :immediate
  end

  ruby_block 'LogRmDirMsg' do
    block do
      writelog "Deleted #{new_resource.dir}"
    end
    action :nothing
  end
end

# runs a PS command (see ps_dirofc fn below)
# output converted to html
# stores it in run_state attribute
# attribute is expanded in html template
action :createreport do
  ruby_block 'dir listing of c:' do
    block do
      # PowerShell Adapter Info - DHCP enabled?
      node.run_state['ps-network'] = ps_net
      node.run_state['ps-network'] = node.run_state['ps-network'].sub '<table>', '<table cellspacing=0 cellpadding=2 border=1>'

      # Auto Services not Running
      node.run_state['ps-service'] = ps_service
      node.run_state['ps-service'] = node.run_state['ps-service'].sub '<table>', '<table cellspacing=0 cellpadding=2 border=1>'

      # Return an ojbect that contains three values
      node.run_state['ntp-obj'] = JSON.parse(ps_ntp)
        # node.run_state['ntp-obj']['NTPTime']
        # node.run_state['ntp-obj']['SYSTime']
        # node.run_state['ntp-obj']['DIFFTime']

      # Date of last Windows update
      node.run_state['last-update'] = ps_lastupdate

      # Chocolatey status
      node.run_state['chocolist'] = ps_chocolist
      node.run_state['chocooutdated'] = ps_chocooutdated

      # Directory listing of c:
      node.run_state['dirofc'] = ps_dirofc
      node.run_state['dirofc'] = node.run_state['dirofc'].sub '<table>', '<table cellspacing=0 cellpadding=2 border=1>'

      # Pings the domain... Indicates which DNS server responds
      node.run_state['ping-domain'] = ps_pingdomain node['domain'].to_s
    end
    action :run
  end

  template 'c:/scripts/clientreport.htm' do
    source 'clientreport.htm.erb'
  end
end

# Appends 3 lines to a log file defined in an attribute
# 1. timestamp
# 2. custom message (install, upgrade or uninstall etc)
# 3. blank line
def writelog(msg)
  logfile = Chef::Util::FileEdit.new(node['installation-parameters']['log-file'].to_s)
  logfile.insert_line_if_no_match('~~~~~~~~~~', "logged: #{Time.new.strftime('%Y-%m-%d %H:%M:%S')}")
  logfile.insert_line_if_no_match('~~~~~~~~~~', "#{msg}")
  logfile.insert_line_if_no_match('~~~~~~~~~~', '')
  logfile.write_file
end

def ps_dirofc
  ps_dirofc_script = <<-EOH
  get-childitem c:\ | select name,creationtime | convertto-html
  EOH
  powershell_out(ps_dirofc_script).stdout.chop.to_s
end

def ps_chocolist
  ps_choco_list_script = <<-EOH
  $pkgs = Invoke-Expression "choco list -l -r"
  foreach ($item in $pkgs) {$ret += $item + '<br>'}
  $ret
  # choco list -l
  EOH
  powershell_out(ps_choco_list_script).stdout.chop.to_s
end

def ps_chocooutdated
  ps_choco_outdated_script = <<-EOH
  $pkgs = Invoke-Expression "choco outdated -r"
  foreach ($item in $pkgs) {$ret += $item + '<br>'}
  $ret
  EOH
  powershell_out(ps_choco_outdated_script).stdout.chop.to_s
end

def ps_net
  ps_net_script = <<-EOH
  Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName . | Select-Object Description, DHCPEnabled, DHCPServer | ConvertTo-Html
  EOH
  powershell_out(ps_net_script).stdout.chop.to_s
end

def ps_service
  ps_service_script = <<-EOH
  Get-Service | Where-Object {($_.status -ne 'running') -and ($_.StartType -eq 'Automatic')} | Select-Object Status, Name, DisplayName, StartType | ConvertTo-Html
  EOH
  powershell_out(ps_service_script).stdout.chop.to_s
end

def ps_ntp
  ps_ntp_script = <<-EOH
  $NTPServer = '129.6.15.28'
  # Build NTP request packet. We'll reuse this variable for the response packet
  $NTPData    = New-Object byte[] 48  # Array of 48 bytes set to zero
  $NTPData[0] = 27                    # Request header: 00 = No Leap Warning; 011 = Version 3; 011 = Client Mode; 00011011 = 27

  # Open a connection to the NTP service
  $Socket = New-Object Net.Sockets.Socket ( 'InterNetwork', 'Dgram', 'Udp' )
  $Socket.SendTimeOut    = 2000  # ms
  $Socket.ReceiveTimeOut = 2000  # ms
  $Socket.Connect( $NTPServer, 123 )

  # Make the request
  $Null = $Socket.Send(    $NTPData )
  $Null = $Socket.Receive( $NTPData )

  # Clean up the connection
  $Socket.Shutdown( 'Both' )
  $Socket.Close()

  # Extract relevant portion of first date in result (Number of seconds since "Start of Epoch")
  $Seconds = [BitConverter]::ToUInt32( $NTPData[43..40], 0 )

  # Add them to the "Start of Epoch", convert to local time zone, and return
  $NTPTime = ([datetime]'1/1/1900' ).AddSeconds( $Seconds ).ToLocalTime()
  $SysTime = Get-Date
  $DiffTime = [math]::abs(($NTPTime - $SysTime).TotalSeconds)

  $obj = New-Object -TypeName PSObject
  Add-Member -InputObject $obj -MemberType NoteProperty -Name NTPTime -Value $NTPTime.ToString()
  Add-Member -InputObject $obj -MemberType NoteProperty -Name SYSTime -Value $SysTime.ToString()
  Add-Member -InputObject $obj -MemberType NoteProperty -Name DIFFTime -Value $DiffTime

  return $obj | ConvertTo-Json
  EOH
  powershell_out(ps_ntp_script).stdout.chop.to_s
end

def ps_lastupdate
  ps_lastupdate_script = <<-EOH
  (get-hotfix | sort installedon | select -last 1).InstalledOn
  EOH
  powershell_out(ps_lastupdate_script).stdout.chop.to_s
end

def ps_pingdomain(domain)
  ps_ping_domain = <<-EOH
  Test-Connection "#{domain}" -count 1 | Select-Object PSComputerName,Address,IPV4Address | ConvertTo-Html
  EOH
  powershell_out(ps_ping_domain).stdout.chop.to_s
end
