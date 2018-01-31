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

## Refactor 1:
Move the write (append) file functionality to a function within the resource file. The re-worked :mkdir and :rmdir now look like this:

```ruby
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

def writelog(msg)
  logfile = Chef::Util::FileEdit.new(node['installation-parameters']['log-file'].to_s)
  logfile.insert_line_if_no_match('~~~~~~~~~~', "logged: #{Time.new.strftime('%Y-%m-%d %H:%M:%S')}")
  logfile.insert_line_if_no_match('~~~~~~~~~~', "#{msg}")
  logfile.insert_line_if_no_match('~~~~~~~~~~', '')
  logfile.write_file
end
```

## Refactor 2
Create an attribute array of pkgs that should be upgraded (kept up-to-date at the latest version)

In Test-Kitchen, set the Attribute thusly:
```ruby
node.default['chocoupgrades']['upgrade-pkgs'] = ['visualstudiocode', 'git', 'chefdk', 'sysinternals', 'notepadplusplus']
```

Then modify the recipe block to loop the array and upgrade each package
```ruby
node['chocoupgrades']['upgrade-pkgs'].each do |item|
  puts item
  chocoupgrades_withlogging 'upgrade' do
    pkg item
    action :upgrade
  end
end
```

Within attributes for a node, role or environment on a Chef server, the .json format will look like:
```json
"chocoupgrades": {
  "upgrade-pkgs": [
    "visualstudiocode",
    "git",
    "chefdk",
    "sysinternals",
    "notepadplusplus"
  ],
```

## New functionality
Build a custom resource to create an html report. The problem to solve is that setting attributes inline for use in a template occurs dueing the compile phase. This is good for consuming the output in a resource that configures the system... either as a guard to decide IF to configure the system or as a parameter with which to configure the system. However, this sequence of execution does NOT work if the goal is to report (in a resource) the new state of the system after the configuration.

The simplest way to ensure (pure ruby) evaluations happen in the desired sequence is to encapsulate them in a ruby_block. One oddity to note is that these blocks seem to have their own scope.

Consider:
```ruby
ruby_block 'dir' do
  block do
    node.run_state['dirofc'] = ps_dirofc
  end
  action :run
end

def ps_dirofc
  ps_dirofc_script = <<-EOH
  get-childitem c:\ | select name,creationtime | convertto-html
  EOH
  powershell_out(ps_dirofc_script).stdout.chop.to_s
end
```

This does not work within a recipe file. Result is `undefined method 'ps_dirofc'`. It will work to place the function inside the ruby_block. (just below `action :run`) Or, both blocks can be move into a custom resource.

Using the same resource file, I add:
```ruby
# runs a PS command (see ps_dirofc fn below)
# output converted to html
# stores it in run_state attribute
# attribute is expanded in html template
action :createreport do
  ruby_block 'dir listing of c:' do
    block do
      node.run_state['dirofc'] = ps_dirofc
      node.run_state['dirofc'] = node.run_state['dirofc'].sub '<table>', '<table cellspacing=0 cellpadding=2 border=1>'
    end
    action :run
  end

  template 'c:/scripts/dirofc.htm' do
    source 'dirofc.htm.erb'
  end
end

def ps_dirofc
  ps_dirofc_script = <<-EOH
  get-childitem c:\ | select name,creationtime | convertto-html
  EOH
  powershell_out(ps_dirofc_script).stdout.chop.to_s
end
```

One of my takeways for this exercise has been that a custom resource file seems to have it's own scope. In this case, A ruby block can find a function within a resource file but not within a recipe. I do not explain that at this time. Just noting it.

My interim conclusion... custom resource files work well for overriding the compile/convergence sequence when needed.

## Another kind of attribute?
node.run_state['name'] can be used to save a value or object between resource blocks, but does not need to be defined in an attribute file or on a Chef Server. In this example I store the output (and even manipulate it) of a powershell command, then utilize this value in the htm.erb template.