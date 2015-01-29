#
# Cookbook Name:: rs-storage
# Attribute:: default
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

# Enable/Disable scheduling backups
default['rs-storage']['schedule']['enable'] = false

# The hour for the backup schedule
default['rs-storage']['schedule']['hour'] = nil

# The minute for the backup schedule
default['rs-storage']['schedule']['minute'] = nil

# The mount point where the device will be mounted
default['rs-storage']['device']['mount_point'] = '/mnt/storage'

# Nickname for the device
default['rs-storage']['device']['nickname'] = 'data_storage'

# Size of the volume to be created
default['rs-storage']['device']['volume_size'] = 10

# I/O Operations Per Second value
default['rs-storage']['device']['iops'] = nil

# Volume type
default['rs-storage']['device']['volume_type'] = nil

# Controller type
default['rs-storage']['device']['controller_type'] = nil

# The filesystem to be used on the device
default['rs-storage']['device']['filesystem'] = 'ext4'

# Amount of time (in seconds) to wait for a volume to detach at decommission
default['rs-storage']['device']['detach_timeout'] = 300

# Whether to destroy volume(s) on decommission
default['rs-storage']['device']['destroy_on_decommission'] = false

# The additional options/flags to use for the `mkfs` command. If the whole device is formatted, the force (-F) flag
# can be used (on ext4 filesystem) to force the operation. This flag may vary based on the filesystem type.
default['rs-storage']['device']['mkfs_options'] = '-F'

# Backup lineage
default['rs-storage']['backup']['lineage'] = nil

# Restore lineage
default['rs-storage']['restore']['lineage'] = nil

# The timestamp to restore backup from a backup taken on or before the timestamp in the same lineage
default['rs-storage']['restore']['timestamp'] = nil

# Daily backups to keep
default['rs-storage']['backup']['keep']['dailies'] = 14

# Weekly backups to keep (Keep weekly backups for 1.5 months)
default['rs-storage']['backup']['keep']['weeklies'] = 6

# Monthly backups to keep
default['rs-storage']['backup']['keep']['monthlies'] = 12

# Yearly backups to keep
default['rs-storage']['backup']['keep']['yearlies'] = 2

# Maximum backups to keep
default['rs-storage']['backup']['keep']['keep_last'] = 60
