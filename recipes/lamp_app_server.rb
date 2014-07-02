#
# Cookbook Name:: otr
# Recipe:: lamp_app_server
#

=begin
#<
This installs the Apache HTTP Server, MySQL client, PHP-FPM,
and the necessary modules to host a PHP application using mod_fastcgi.

This also installs the [database cookbook].

[database cookbook]: http://community.opscode.com/cookbooks/database
#>
=end

include_recipe 'otr::_common_system'
include_recipe 'otr::_apache_server'
include_recipe 'apache2::mod_fastcgi'
include_recipe 'mysql::client'
include_recipe 'database::mysql'
include_recipe 'php::default'
include_recipe 'php::fpm'
include_recipe 'php::module_mysql'
include_recipe 'otr::services'

apache_module 'actions' do
  enable true
end

node['otr']['apps'].select { |a| a[:type] == 'lamp' }.each do |app|
  otr_lamp_app app[:name] do
    moniker app[:moniker]
    service resources(otr_service: app[:service])
    action app[:action] if app[:action]
  end
end

include_recipe 'otr::deployment'
