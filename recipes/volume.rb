#
# Cookbook Name:: rs-storage
# Recipe:: volume
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

detach_timeout = node['rs-storage']['device']['detach_timeout'].to_i
device_nickname = node['rs-storage']['device']['nickname']
size = node['rs-storage']['device']['volume_size'].to_i

execute "set decommission timeout to #{detach_timeout}" do
  command "rs_config --set decommission_timeout #{detach_timeout}"
  not_if "[ `rs_config --get decommission_timeout` -eq #{detach_timeout} ]"
end


# Cloud-specific volume options
volume_options = {}
volume_options[:iops] = node['rs-storage']['device']['iops'] if node['rs-storage']['device']['iops']

# rs-storage/restore/lineage is empty, creating new volume
if node['rs-storage']['restore']['lineage'].to_s.empty?
  log "Creating a new volume '#{device_nickname}' with size #{size}"
  rightscale_volume device_nickname do
    size size
    options volume_options
    action [:create, :attach]
  end
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
end

# Encrypt if enabled
if node['rs-storage']['device']['encryption'] == true || node['rs-storage']['device']['encryption'] == 'true'
  if node['rs-storage']['device']['encryption_key']

    # Verify cryptsetup is installed
    package 'cryptsetup'

    execute 'cryptsetup format device' do
      environment 'ENCRYPTION_KEY' => node['rs-storage']['device']['encryption_key']
      command lazy { "echo -n ${ENCRYPTION_KEY} | cryptsetup luksFormat #{node['rightscale_volume'][nickname]['device']} --batch-mode" }
      not_if do
        isluks_command = "cryptsetup isLuks #{node['rightscale_volume'][nickname]['device']}"
        Mixlib::ShellOut.new(isluks_command).run_command
      end
    end

    execute 'cryptsetup open device' do
      environment 'ENCRYPTION_KEY' => node['rs-storage']['device']['encryption_key']
      command lazy { "echo -n ${ENCRYPTION_KEY} | cryptsetup luksOpen #{node['rightscale_volume'][nickname]['device']} encrypted-#{nickname} --key-file=-" }
      not_if { ::File.exists?("/dev/mapper/encrypted-#{nickname}") }
    end
  else
    Chef::Log.info "Encryption key not set - device encryption not enabled"
  end
end

filesystem nickname do
  fstype node['rs-storage']['device']['filesystem']
  device(lazy do
    if (node['rs-storage']['device']['encryption'] == true || node['rs-storage']['device']['encryption'] == 'true') && node['rs-storage']['device']['encryption_key']
      "/dev/mapper/encrypted-#{nickname}"
    else
      node['rightscale_volume'][nickname]['device']
    end
  end)
  mkfs_options node['rs-storage']['device']['mkfs_options']
  mount node['rs-storage']['device']['mount_point']
  action (node['rs-storage']['restore']['lineage'].to_s.empty? ? [:create] : []) + [:enable, :mount]
end
