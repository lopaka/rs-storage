#
# Cookbook Name:: rs-storage
# Recipe:: stripe
#
# Copyright (C) 2014 RightScale, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

marker "recipe_start_rightscale" do
  template "rightscale_audit_entry.erb"
end

device_count = node['rs-storage']['device']['count'].to_i
nickname = node['rs-storage']['device']['nickname']
size = node['rs-storage']['device']['volume_size'].to_i

raise 'rs-storage/device/count should be at least 2 for setting up stripe' if device_count < 2

detach_timeout = node['rs-storage']['device']['detach_timeout'].to_i * device_count

execute "set decommission timeout to #{detach_timeout}" do
  command "rs_config --set decommission_timeout #{detach_timeout}"
  not_if "[ `rs_config --get decommission_timeout` -eq #{detach_timeout} ]"
end

each_device_size = (size.to_f / device_count.to_f).ceil

Chef::Log.info "Total size is: #{size}"
Chef::Log.info "Device count in logical volume is set to: #{device_count}"
Chef::Log.info "Each device in the logical volume will be created of size: #{each_device_size}"

device_nicknames = []

# Cloud-specific volume options
volume_options = {}
volume_options[:iops] = node['rs-storage']['device']['iops'] if node['rs-storage']['device']['iops']

# Install packages required for setting up LVM
include_recipe 'lvm::default'

# rs-storage/restore/lineage is empty, creating new volume(s) and setting up LVM
if node['rs-storage']['restore']['lineage'].to_s.empty?
  1.upto(device_count) do |device_num|
    device_nicknames << "#{nickname}_#{device_num}"
    rightscale_volume "#{nickname}_#{device_num}" do
      size each_device_size
      options volume_options
      action [:create, :attach]
    end
  end
# rs-storage/restore/lineage is set, restore from the backup
else
  rightscale_backup nickname do
    lineage node['rs-storage']['restore']['lineage']
    timestamp node['rs-storage']['restore']['timestamp'].to_i if node['rs-storage']['restore']['timestamp']
    size each_device_size
    options volume_options
    action :restore
  end
end

# Remove any characters other than alphanumeric and dashes and replace with dashes
sanitized_nickname = nickname.downcase.gsub(/[^-a-z0-9]/, '-')

# Setup LVM on the volumes. The following resources will:
#   - initialize the physical volumes for use by LVM
#   - create volume group and logical volume
#   - format and mount the logical volume
lvm_volume_group "#{sanitized_nickname}-vg" do
  physical_volumes(lazy do
    if node['rs-storage']['restore']['lineage'].to_s.empty?
      device_nicknames.map { |nickname| node['rightscale_volume'][nickname]['device'] }
    else
      node['rightscale_backup'][nickname]['devices']
    end
  end)
end

lvm_logical_volume "#{sanitized_nickname}-lv" do
  group "#{sanitized_nickname}-vg"
  size '100%VG'
  stripes device_count
  stripe_size node['rs-storage']['device']['stripe_size']
end

# Encrypt if enabled
if node['rs-storage']['device']['encryption']
  if node['rs-storage']['device']['encryption_key']
    execute 'cryptsetup format device' do
      command "echo '#{node['rs-storage']['device']['encryption_key']}' | cryptsetup luksFormat /dev/mapper/#{sanitized_nickname}-vg-#{sanitized_nickname}-lv -"
      not_if "cryptsetup isLuks /dev/mapper/#{sanitized_nickname}-vg-#{sanitized_nickname}-lv"
    end

    execute 'cryptsetup open device' do
      command "echo '#{node['rs-storage']['device']['encryption_key']}' | cryptsetup luksOpen /dev/mapper/#{sanitized_nickname}-vg-#{sanitized_nickname}-lv encrypted-#{sanitized_nickname}-vg-#{sanitized_nickname}-lv --key-file -"
      not_if ::File.exists?("/dev/mapper/encrypted-#{sanitized_nickname}-vg-#{sanitized_nickname}-lv")
    end
  else
    Chef::Log.info "Encryption key not set - device encryption not enabled"
  end
end

# Format device
filesystem nickname do
  fstype node['rs-storage']['device']['filesystem']
  device(lazy do
    if node['rs-storage']['device']['encryption'] && node['rs-storage']['device']['encryption_key']
      node['rightscale_volume'][nickname]['device']
    else
      "/dev/mapper/encrypted-#{sanitized_nickname}-vg-#{sanitized_nickname}-lv"
    end
  end)
  mkfs_options node['rs-storage']['device']['mkfs_options']
  mount node['rs-storage']['device']['mount_point']
  action [:create, :enable, :mount]
end
