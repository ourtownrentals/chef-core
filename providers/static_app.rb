#
# Cookbook Name:: core
# Provider:: static_app
#

include Opscode::OpenSSL::Password

def whyrun_supported?
  true
end

action :create do
  converge_by("Creating #{@new_resource}") do
    create_static_app
  end
end

action :delete do
  converge_by("Deleting #{@new_resource}") do
    delete_static_app
  end
end

private

def set_attributes
  new_resource.type = :static
  new_resource.group = node['nginx']['group']
  new_resource.dir = "#{new_resource.service.dir}/#{new_resource.moniker}"
  new_resource.conf_dir = "#{new_resource.service.nginx_conf_dir}/#{new_resource.moniker}.d"
  new_resource.shared_dir =
    "#{new_resource.service.dir}/shared/#{new_resource.moniker}" unless new_resource.storage.empty?
end

def create_static_app
  set_attributes
  set_storage_host

  fail 'No nginx conf directory.' if new_resource.service.nginx_conf_dir.nil?

  # Create `/srv/service_name/shared/moniker`.
  directory "static_app_#{new_resource.shared_dir}" do
    path new_resource.shared_dir
    group new_resource.group
    mode '0750'
    not_if { new_resource.storage.empty? }
  end

  # Mount storage directories.
  new_resource.storage.each do |storage, params|
    search_str = "chef_environment:#{node.chef_environment} AND tags:storage-master" \
                 " AND core_storage_#{storage}_enabled:true"
    storage_node =
      partial_search(:node, search_str, keys: {
        'network' => ['network'],
        'core' => ['core']
      }
    ).first

    directory "lamp_app_#{new_resource.shared_dir}/#{params[:path]}" do
      path "#{new_resource.shared_dir}/#{params[:path]}"
      recursive true
      not_if { Dir.exist?("#{new_resource.shared_dir}/#{params[:path]}") }
    end

    mount "lamp_app_#{new_resource.shared_dir}/#{params[:path]}" do
      mount_point "#{new_resource.shared_dir}/#{params[:path]}"
      device(
        Chef::Recipe::PrivateNetwork.new(storage_node).ip +
        ":#{node['core']['storage_dir']}/#{storage}"
      )
      fstype 'nfs'
      options params[:options]
    end
  end

  # Create `/etc/nginx/services/service_name/moniker.d`.
  directory "static_app_#{new_resource.conf_dir}" do
    path new_resource.conf_dir
    notifies :reload, 'service[nginx]'
  end
end

def delete_static_app
  set_attributes

  # Unmount storage directories.
  new_resource.storage.each do |storage, params|
    mount "lamp_app_#{new_resource.shared_dir}/#{params[:path]}" do
      mount_point "#{new_resource.shared_dir}/#{params[:path]}"
      action :umount
    end
  end

  # Delete `/srv/service_name/shared/moniker`.
  directory "static_app_#{new_resource.shared_dir}" do
    path new_resource.shared_dir
    recursive true
    action :delete
    not_if { new_resource.storage.empty? }
  end

  # Delete `/etc/nginx/services/service_name/moniker.d`.
  directory "static_app_#{new_resource.conf_dir}" do
    path new_resource.conf_dir
    recursive true
    action :delete
    notifies :reload, 'service[nginx]'
    only_if { Dir.exist?(new_resource.conf_dir) }
  end
end
