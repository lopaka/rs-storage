#
# Cookbook Name:: rs-storage
# Recipe:: volume
#
# Copyright (C) 2015 RightScale, Inc.
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

detach_timeout = node['rs-storage']['device']['detach_timeout'].to_i
device_nickname = node['rs-storage']['device']['nickname']
size = node['rs-storage']['device']['volume_size'].to_i

execute "set decommission timeout to #{detach_timeout}" do
  command "rs_config --set decommission_timeout #{detach_timeout}"
  not_if "[ `rs_config --get decommission_timeout` -eq #{detach_timeout} ]"
end

# Determine how many volumes to attach based on mount points provided
mount_points = node['rs-storage']['device']['mount_point'].split(/\s*,\s*/)

# Cloud-specific volume options
volume_options = {}
volume_options[:iops] = node['rs-storage']['device']['iops'] if node['rs-storage']['device']['iops']
volume_options[:volume_type] = node['rs-storage']['device']['volume_type'] if node['rs-storage']['device']['volume_type']
volume_options[:controller_type] = node['rs-storage']['device']['controller_type'] if node['rs-storage']['device']['controller_type']

# rs-storage/restore/lineage is empty, creating new volume(s)
if node['rs-storage']['restore']['lineage'].to_s.empty?
  log "Creating new volumes '#{device_nickname}' each with size #{size}"
  mount_points.to_enum.with_index(1) do |mount_point, device_num|
    rightscale_volume "#{device_nickname}_#{device_num}" do
      size size
      options volume_options
      action [:create, :attach]
    end

    filesystem "#{device_nickname}_#{device_num}" do
      fstype node['rs-storage']['device']['filesystem']
      device lazy { node['rightscale_volume']["#{device_nickname}_#{device_num}"]['device'] }
      mkfs_options node['rs-storage']['device']['mkfs_options']
      mount mount_point
      action [:create, :enable, :mount]
    end
  end
# rs-storage/restore/lineage is set, restore from the backup
else
  lineage = node['rs-storage']['restore']['lineage']
  timestamp = node['rs-storage']['restore']['timestamp']

  message = "Restoring volume '#{device_nickname}' from backup using lineage '#{lineage}'"
  message << " and using timestamp '#{timestamp}'" if timestamp

  log message

  rightscale_backup device_nickname do
    lineage node['rs-storage']['restore']['lineage']
    timestamp node['rs-storage']['restore']['timestamp'].to_i if node['rs-storage']['restore']['timestamp']
    size size
    options volume_options
    action :restore
  end

  mount_points.to_enum.with_index(0) do |mount_point, device_num|
    directory mount_point do
      recursive true
    end

    mount mount_point do
      fstype node['rs-storage']['device']['filesystem']
      device lazy { node['rightscale_backup'][device_nickname]['devices'][device_num] }
      action [:mount, :enable]
    end
  end
end
