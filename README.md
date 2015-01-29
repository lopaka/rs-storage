# rs-storage cookbook

[![Release](https://img.shields.io/github/release/rightscale-cookbooks/rs-storage.svg?style=flat)][release]
[![Build Status](https://img.shields.io/travis/rightscale-cookbooks/rs-storage.svg?style=flat)][travis]

[release]: https://github.com/rightscale-cookbooks/rs-storage/releases/latest
[travis]: https://travis-ci.org/rightscale-cookbooks/rs-storage

Provides recipes for managing volumes on a Server in a RightScale supported cloud which include:

* Creation of volumes
* Taking backups of volumes
* Restoring from backups
* Schedule periodic backups
* Detaching and deleting volumes when server is decommissioned.

Github Repository: [https://github.com/rightscale-cookbooks/rs-storage](https://github.com/rightscale-cookbooks/rs-storage)

# Requirements

* Requires Chef 11 or higher
* Requires Ruby 1.9 of higher
* Platform
  * Ubuntu 12.04
  * CentOS 6
* Cookbooks
  * [chef_handler](http://community.opscode.com/cookbooks/chef_handler)
  * [filesystem](http://community.opscode.com/cookbooks/filesystem)
  * [lvm](http://community.opscode.com/cookbooks/lvm)
  * [marker](http://community.opscode.com/cookbooks/marker)
  * [rightscale_volume](http://community.opscode.com/cookbooks/rightscale_volume)
  * [rightscale_backup](http://community.opscode.com/cookbooks/rightscale_backup)

# Usage

## Creating a new volume

To create a new volume, run the `rs-storage::volume` recipe with the following attributes set:

- `node['rs-storage']['device']['nickname']` - the nickname of the volume
- `node['rs-storage']['device']['volume_size']` - the size of the volume to create
- `node['rs-storage']['device']['filesystem']` - the filesystem to use on the volume
- `node['rs-storage']['device']['mount_point']` - the location to mount the volume

This will create a new volume, attach it to the server, format it with the filesystem specified, and mount it on the
location specified.

### Provisioned IOPS on EC2

To create a volume with IOPS on EC2, set the following attribute before running `rs-storage::volume` recipe:

- `node['rs-storage']['device']['iops']` - the value of IOPS to use

## Backing up volume(s) & Cleaning up backups

To create a backup of all volumes attached to the server, run the `rs-storage::backup` recipe with the following
attributes set:

- `node['rs-storage']['backup']['lineage']` - the lineage to be used for the backup

The backup process will create a snapshot of all volumes attached to the server (except the boot disk if there is one).
The backup recipe also handles the cleanup of old volume snapshots and accepts the following attributes:

- `node['rs-storage']['backup']['keep']['keep_last']` - number of last backups to keep from deleting
- `node['rs-storage']['backup']['keep']['dailies']` - number of daily backups to keep
- `node['rs-storage']['backup']['keep']['weeklies']` - number of weekly backups to keep
- `node['rs-storage']['backup']['keep']['monthlies']` - number of monthly backups to keep
- `node['rs-storage']['backup']['keep']['yearlies']` - number of yearly backups to keep

This will cleanup the old snapshots on the cloud based on the criteria specified.

## Restoring a volume from a backup

To restore a volume from backup, run the `rs-storage::volume` recipe with the same set of attributes mentioned in the
[previous section](#creating-a-new-volume) along with the following attribute:

- `node['rs-storage']['restore']['lineage']` - the lineage to restore the backup from

This will restore the volume from the backup instead of creating a new one. By default, the backup with the latest
timestamp will be restored. To restore a backup from a specific timestamp, set the following attribute:

- `node['rs-storage']['restore']['timestamp']` - the timestamp of the backup to restore from (in seconds since UNIX
  epoch)

## Scheduling automated backups of volume(s)

To schedule automated backups, run the `rs-storage::schedule` recipe with the following attributes set:

- `node['rs-storage']['schedule']['enable']` - to enable/disable automated backups
- `node['rs-storage']['schedule']['hour']` - the hour to take the backup on (should use crontab syntax)
- `node['rs-storage']['schedule']['minute']` - the minute to take the backup on (should use crontab syntax)
- `node['rs-storage']['backup']['lineage']` - the lineage name to be used for the backup

This will create a crontab entry to run the `rs-storage::backup` recipe periodically at the given minute and hour. To
disable the automated backups, simply set `node['rs-storage']['schedule']['enable']` to `false` and rerun the
`rs-storage::schedule` recipe and this will remove the crontab entry.

## Deleting volume(s)

This operation should be part of the decommission bundle in a RightScale ServerTemplate where the volumes attached to
the server are detached and deleted from the cloud but this can also be used as an operational recipe. This recipe will
do nothing in the following conditions:

- when the server enters a stop state
- when the server reboots

This recipe also has a safety attribute `node['rs-storage']['device']['destroy_on_decommission']`. This attribute will
be set to `false` by default and should be overridden and set to `true` in order for the devices to be detached and
deleted.

# Attributes

- `node['rs-storage']['device']['nickname']` - The nickname for the device or the logical volume comprising multiple of
  devices. Default is `'data_storage'`.
- `node['rs-storage']['device']['mount_point']` - The mount point for the device. Default is `'/mnt/storage'`.
- `node['rs-storage']['device']['volume_size']` - The size (in gigabytes) of the volume to be created. If multiple
  devices are used, this will be the total size of the logical volume. Default is `10`.
- `node['rs-storage']['device']['count']` - The number of devices to be created for the logical volume. Default is `2`.
- `node['rs-storage']['device']['iops']` - The IOPS value to be used for EC2 Provisioned IOPS. This attribute should
  only be used with Amazon EC2. Default is `nil`.
- `node['rs-storage']['device']['filesystem']` - The filesystem to be used on the device. Default is `'ext4'`.
- `node['rs-storage']['device']['detach_timeout']` - Amount of time (in seconds) to wait for a volume to detach during
  the decommission of the server. Default is `300` (5 minutes).
- `node['rs-storage']['device']['destroy_on_decommission']` - Whether to destroy the device during the decommission of
  the server. Default is `false`.
- `node['rs-storage']['device']['mkfs_options']` - Additional mkfs options for formatting the device. Default is `'-F'`
  which is required to avoid warnings about formatting the whole device.
- `node['rs-storage']['backup']['lineage']` - The backup lineage. Default is `nil`.
- `node['rs-storage']['backup']['keep']['keep_last']` - Maximum snapshots to keep. Default is `60`.
- `node['rs-storage']['backup']['keep']['dailies']` - Number of daily backups to keep. Default is `14`.
- `node['rs-storage']['backup']['keep']['weeklies']` - Number of weekly backups to keep. Default is `6`.
- `node['rs-storage']['backup']['keep']['monthlies']` - Number of monthly backups to keep. Default is `12`.
- `node['rs-storage']['backup']['keep']['yearlies']` - Number of yearly backups to keep. Default is `2`.
- `node['rs-storage']['restore']['lineage']` - The name of the lineage to restore the backups from. Default is `nil`.
- `node['rs-storage']['restore']['timestamp']` - The timestamp to restore backup taken on or before the timestamp in the
  same lineage. Default is `nil`.
- `node['rs-storage']['schedule']['enable']` - Enable/disable automated backups. Default is `false`.
- `node['rs-storage']['schedule']['hour']` - The backup schedule hour. Default is `nil`.
- `node['rs-storage']['schedule']['minute']` - The backup schedule minute. Default is `nil`.


# Recipes

## `rs-storage::default`

Simply includes the `rightscale_volume::default` and `rightscale_backup::default` recipes to meet the requirements of
using the resources in these cookbooks.

## `rs-storage::volume`

Creates a new volume from scratch or from an existing backup based on the value provided in the
`node['rs-storage']['restore']['lineage']` attribute. If this attribute is set, the volume will be restored from a
backup matching this lineage otherwise a new volume will be created from scratch. This recipe will also format the
volume using the filesystem specified in `node['rs-storage']['device']['filesystem']` and mount the volume on the
location specified in `node['rs-storage']['device']['mount_point']`.

## `rs-storage::backup`

Takes a backup of all volumes attached to the server (except boot disks if there are any) with the lineage specified
in the `node['rs-storage']['backup']['lineage']` attribute. During the backup process, the filesystem will be frozen.i
The filesystem will be unfrozen even if the backup process fails with the help of a chef exception handler. This recipe
will also clean up the volume snapshots based on the criteria specified in the `rs-storage/backup/keep/*` attributes.

## `rs-storage::schedule`

Adds or removes the crontab entry for taking backups periodically at the minute and hour provided via
`node['rs-storage']['schedule']['minute']` and `node['rs-storage']['schedule']['hour']` attributes. The recipe uses the
`node['rs-storage']['schedule']['enable']` attribute to determine wheter to add or remove the crontab entry.

## `rs-storage::decommission`

If the `node['rs-storage']['device']['destroy_on_decommission']` attribute is set to true, this recipe detaches and
deletes the volumes attached to the server. This operation will be skipped if the server is entering the stop state or
rebooting.

# Author

Author:: RightScale, Inc. (<cookbooks@rightscale.com>)
