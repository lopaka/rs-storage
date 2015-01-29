#
# Cookbook Name:: rs-storage
# Recipe:: backup
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

marker 'recipe_start_rightscale' do
  template 'rightscale_audit_entry.erb'
end

include_recipe 'chef_handler::default'

# Create the backup error handler
cookbook_file "#{node['chef_handler']['handler_path']}/rs-storage_backup.rb" do
  source 'backup_error_handler.rb'
  action :create
end

# Enable the backup error handler so the filesystem is unfrozen in case of a backup failure
chef_handler 'Rightscale::BackupErrorHandler' do
  source "#{node['chef_handler']['handler_path']}/rs-storage_backup.rb"
  action :enable
end

device_nickname = node['rs-storage']['device']['nickname']

# Determine how many volumes to freeze based on mount points provided
mount_points = node['rs-storage']['device']['mount_point'].split(/\s*,\s*/)

mount_points.to_enum.with_index(1) do |mount_point, device_num|
  log "Freezing the filesystem mounted on #{mount_point}"
  filesystem "freeze #{device_nickname}_#{device_num}" do
    label "#{device_nickname}_#{device_num}"
    mount mount_point
    action :freeze
  end
end

log "Taking a backup of lineage '#{node['rs-storage']['backup']['lineage']}'"

rightscale_backup device_nickname do
  lineage node['rs-storage']['backup']['lineage']
  action :create
end

mount_points.to_enum.with_index(1) do |mount_point, device_num|
  log "Unfreezing the filesystem mounted on #{mount_point}"
  filesystem "unfreeze #{device_nickname}_#{device_num}" do
    label "#{device_nickname}_#{device_num}"
    mount mount_point
    action :unfreeze
  end
end

log 'Cleaning up old snapshots'

rightscale_backup device_nickname do
  lineage node['rs-storage']['backup']['lineage']
  keep_last node['rs-storage']['backup']['keep']['keep_last'].to_i
  dailies node['rs-storage']['backup']['keep']['dailies'].to_i
  weeklies node['rs-storage']['backup']['keep']['weeklies'].to_i
  monthlies node['rs-storage']['backup']['keep']['monthlies'].to_i
  yearlies node['rs-storage']['backup']['keep']['yearlies'].to_i
  action :cleanup
end
