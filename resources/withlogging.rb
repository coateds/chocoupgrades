# To learn more about Custom Resources, see https://docs.chef.io/custom_resources.html
# Bump

property :dir, String
property :pkg, String

action :install do
  chocolatey_package new_resource.pkg do
    action :upgrade
    notifies :run, 'ruby_block[LogPkgMsg]', :immediate
  end

  ruby_block 'LogPkgMsg' do
    block do
      logfile = Chef::Util::FileEdit.new(node['installation-parameters']['log-file'].to_s)
      logfile.insert_line_if_no_match('~~~~~~~~~~', "logged: #{Time.new.strftime('%Y-%m-%d %H:%M:%S')}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', "Installed #{new_resource.pkg}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', '')
      logfile.write_file
    end
    action :nothing
  end
end

action :mkdir do
  directory new_resource.dir do
    action :create
    notifies :run, 'ruby_block[LogDirMsg]', :immediate
  end

  ruby_block 'LogDirMsg' do
    block do
      logfile = Chef::Util::FileEdit.new(node['installation-parameters']['log-file'].to_s)
      logfile.insert_line_if_no_match('~~~~~~~~~~', "logged: #{Time.new.strftime('%Y-%m-%d %H:%M:%S')}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', "Created #{new_resource.dir}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', '')
      logfile.write_file
    end
    action :nothing
  end
end

action :rmdir do
  directory new_resource.dir do
    action :delete
    notifies :run, 'ruby_block[LogRmDirMsg]', :immediate
  end

  ruby_block 'LogRmDirMsg' do
    block do
      logfile = Chef::Util::FileEdit.new(node['installation-parameters']['log-file'].to_s)
      logfile.insert_line_if_no_match('~~~~~~~~~~', "logged: #{Time.new.strftime('%Y-%m-%d %H:%M:%S')}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', "Deleted #{new_resource.dir}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', '')
      logfile.write_file
    end
    action :nothing
  end
end
