# chocoupgrades

Chef demonstrator for using custom resources

This cookbook adds a logging function to select resources. The original intent was to run automatic chocolatey package upgrades and log each upgrade occurance to an installation log. The trick was to find a way to customize the logged message with the name of the pakcage being upgraded. It was not possible to use a single attribute fed to a function for this because of the 2 phases of a Chef client run.

That is, the attribute(s) would get set in the first phase of the run and the chocolatey_package would install or upgrade during the second phase. This meant that two instances of an install in the same Chef client run would suffer an overwrite problem.

I solved this problem by putting a pair of reasouces in a custom resource. The first, chocolatey_package resource would perform the upgrade as needed and notify a ruby_block resource that would log the event. This provided a great opportunity to explore custom resources and work to ensure all required code would occur in the execution phase by using ruby_block resources.

For development purposes, I started with `directory` resources as it was clear I needed to work the case where the custom resource gets called twice in one run. It was easier to delete directories on the client to reset for each run. The resouce file ends up looking like this. (includes both a create and delete function)

```ruby
property :dir, String

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
```

The first line defines a property `dir` that is supplied from the calling resource block in a recipe. The calling resource blocks will look like this:

```ruby
chocoupgrades_withlogging 'make dir' do
  dir 'c:\MyDir'
  action :mkdir
end

chocoupgrades_withlogging 'remove dir' do
  dir 'c:\MyDir'
  action :rmdir
end
```

A couple of rules about custom resources:
1. Call a resouce with [cookbook_name]_[resourcefile_name]. However, it appears that the cookbook name cannot have any hyphens in it. (I still need to confirm this)
2. All resouce blocks must be encapsulated in action blocks. (In this case :mkdir and :rmdir)
3. Properties are passed as options to the resource block. In this case `dir`
4. references to the passed property now takes the form: `new_resource.[prop_name]
5. The default action is the first action in the resource file.

The big advantage (solution) here was the ability to use the property (dir) in both the directory resource block and the ruby block that appends to the log. Both of these blocks appear to be running in the execution/convergence phase.

Once the logic for handling multiple resouces was solved, it was time to move on to chocolatey_package resources. I built three actions, :install, :upgrade and :uninstall.

* use :install in this process to go to a specific version
* use :upgrade to go to the latest version (whether or not ANY version is installed)

```ruby
property :pkg, String
property :ver, String

action :install do
  chocolatey_package new_resource.pkg do
    action :install
    version new_resource.ver.to_s
    notifies :run, 'ruby_block[LogInstallPkgMsg]', :immediate
  end

  ruby_block 'LogInstallPkgMsg' do
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

action :uninstall do
  chocolatey_package new_resource.pkg do
    action :uninstall
    notifies :run, 'ruby_block[LogUninstallPkgMsg]', :immediate
  end

  ruby_block 'LogUninstallPkgMsg' do
    block do
      logfile = Chef::Util::FileEdit.new(node['installation-parameters']['log-file'].to_s)
      logfile.insert_line_if_no_match('~~~~~~~~~~', "logged: #{Time.new.strftime('%Y-%m-%d %H:%M:%S')}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', "Uninstalled #{new_resource.pkg}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', '')
      logfile.write_file
    end
    action :nothing
  end
end

action :upgrade do
  chocolatey_package new_resource.pkg do
    action :upgrade
    notifies :run, 'ruby_block[LogUpgradePkgMsg]', :immediate
  end

  ruby_block 'LogUpgradePkgMsg' do
    block do
      logfile = Chef::Util::FileEdit.new(node['installation-parameters']['log-file'].to_s)
      logfile.insert_line_if_no_match('~~~~~~~~~~', "logged: #{Time.new.strftime('%Y-%m-%d %H:%M:%S')}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', "Upgraded #{new_resource.pkg}")
      logfile.insert_line_if_no_match('~~~~~~~~~~', '')
      logfile.write_file
    end
    action :nothing
  end
end
```

Call these 3 resources like this:
```ruby
chocoupgrades_withlogging 'install notepad++' do
  pkg 'notepadplusplus'
  # ver '7.5.3'  --  used only with :install
  action :upgrade/:uninstall/:install
end
```