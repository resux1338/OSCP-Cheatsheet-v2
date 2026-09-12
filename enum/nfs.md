# NFS and RPCbind

[← Service index](service-triage.md) · [Linux NFS privilege escalation](../linux/groups-and-nfs.md#nfs)

RPCbind can show which NFS-related services are registered. `showmount` lists exports when the server exposes the mount service; an empty result does not rule out an NFSv4-only server.

```bash
rpcinfo -p <target-ip>
showmount -e <target-ip>
```

Mount a known export read-only first, then inspect ownership and content:

```bash
sudo mkdir -p /mnt/target-nfs
sudo mount -t nfs -o ro <target-ip>:/export /mnt/target-nfs
find /mnt/target-nfs -maxdepth 2 -type f -ls
stat -c '%u:%g %A %n' /mnt/target-nfs
sudo umount /mnt/target-nfs
```

If mounting fails, check the export path, permitted client address, NFS version, and whether TCP 2049 is reachable. The server may present a different path under NFSv4. Files can also be useful for credentials, scripts, backups, or writable paths without implying root access. `no_root_squash` matters only after you confirm the export and permissions.

References: [`showmount`](https://man7.org/linux/man-pages/man8/showmount.8.html) · [NFS exports](https://man7.org/linux/man-pages/man5/exports.5.html).
