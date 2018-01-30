#
# Cookbook:: chocoupgrades
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.
# Bump

file node['installation-parameters']['log-file'].to_s

chocoupgrades_withlogging 'make dir' do
  dir 'c:\Booger'
  action :rmdir
end

chocoupgrades_withlogging 'make dir' do
  dir 'c:\Boogertu'
  action :rmdir
end

# chocoupgrades_withlogging 'install git' do
#   pkg 'git'
#   action :upgrade
# end
#
# chocoupgrades_withlogging 'install VSCode' do
#   pkg 'visualstudiocode'
#   action :upgrade
# end
#
# chocoupgrades_withlogging 'install ChefDK' do
#   pkg 'chefdk'
#   action :upgrade
# end

# loop the array of pkgs to upgrade
# effectively keeping the pakg to the latest version in chocolatey
node['chocoupgrades']['upgrade-pkgs'].each do |item|
  puts item
  chocoupgrades_withlogging 'upgrade' do
    pkg item
    action :upgrade
  end
end
