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