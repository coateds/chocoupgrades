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

The first line defines a property `dir` that is supplied from the calling resource block in a recipe.