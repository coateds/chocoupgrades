#
# Cookbook:: chocoupgrades
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.
# Bump

file node['installation-parameters']['log-file'].to_s

# chocoupgrades_withlogging 'make dir' do
#   dir 'c:\Booger'
#   action :rmdir
# end

# chocoupgrades_withlogging 'make dir' do
#   dir 'c:\Boogertu'
#   action :rmdir
# end

node['chocoupgrades']['make-directories'].each do |item|
  chocoupgrades_withlogging 'mkdir' do
    dir item
    action :mkdir
  end
end

node['chocoupgrades']['remove-directories'].each do |item|
  chocoupgrades_withlogging 'rmdir' do
    dir item
    action :rmdir
  end
end

# loop the array of pkgs to upgrade
# effectively keeping the pakg to the latest version in chocolatey
node['chocoupgrades']['upgrade-pkgs'].each do |item|
  puts item
  chocoupgrades_withlogging 'upgrade' do
    pkg item
    action :upgrade
  end
end

# Remove packages in the array attribute
node['chocoupgrades']['remove-pkgs'].each do |item|
  chocoupgrades_withlogging 'remove' do
    pkg item
    action :uninstall
  end
end