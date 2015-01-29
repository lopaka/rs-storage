#
# Cookbook Name:: rs-storage
# Recipe:: decommission
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

# Check for the safety attribute first
if node['rs-storage']['device']['destroy_on_decommission'] != true &&
  node['rs-storage']['device']['destroy_on_decommission'] != 'true'
  log "rs-storage/device/destroy_on_decommission is set to '#{node['rs-storage']['device']['destroy_on_decommission']}'" +
    " skipping..."
# Check 'rs_run_state' and skip if the instance is rebooting or entering the stop state
elsif ['shutting-down:reboot', 'shutting-down:stop', 'shutting-down:unknown'].include?(get_rs_run_state)
  log 'Skipping deletion of volumes as the instance is either rebooting or entering the stop state...'
# Detach and delete the volumes if the above safety conditions are satisfied
else
  device_nickname = node['rs-storage']['device']['nickname']

  # Determine how many volumes to detached based on mount points provided
  mount_points = node['rs-storage']['device']['mount_point'].split(/\s*,\s*/)

  mount_points.to_enum.with_index(1) do |mount_point, device_num|
    # Unmount the volumes
    log "Unmounting #{mount_point}"
    # There might still be some open files from the mount point. Just ignore the failure for now.
    mount mount_point do
      device lazy { node['rightscale_volume']["#{device_nickname}_#{device_num}"]['device'] }
      ignore_failure true
      action [:umount, :disable]
      only_if { node.attribute?('rightscale_volume') && node['rightscale_volume'].attribute?(device_nickname) }
    end

    # Detach and delete the volume
    rightscale_volume "#{device_nickname}_#{device_num}" do
      action [:detach, :delete]
    end
  end
end
