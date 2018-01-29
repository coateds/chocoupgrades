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

# chocoupgrades_withlogging 'install pkg' do
#   pkg 'curl'
#   action :install
# end

chocoupgrades_withlogging 'install git' do
  pkg 'git'
  action :install
end

chocoupgrades_withlogging 'install VSCode' do
  pkg 'visualstudiocode'
  action :install
end

chocoupgrades_withlogging 'install ChefDK' do
  pkg 'chefdk'
  action :install
end
