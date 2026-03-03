# Local file storage

## Description
Local file storage involves storing data on local disks or NAS, using file systems like NTFS for Windows or ext4 for Linux.

## Features
- **Access**: Fast, direct.
- **Redundancy**: RAID.
- **Sharing**: SMB/NFS.
- **Backup**: Tools like rsync.
- **Encryption**: BitLocker.
- **Quotas**: Usage limits.

## Relevance to Current Build
For non-DB data in Storage, like GIS files, images.

## Related Components
- [[Docker volumes]]: Container storage.
- [[06_GIS/QGIS projects .qgz|QGIS projects (.qgz)]]: Files.
- [[Shapefiles]]: Stored locally.
- [[Paperless-ngx]]: Document files.
