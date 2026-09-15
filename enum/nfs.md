# NFS and RPCbind

[← Service index](service-triage.md) · [Linux NFS privilege escalation](../linux/groups-and-nfs.md#nfs)

Run RPCbind + `showmount`; blank `showmount` may still mean NFSv4-only.

```bash
rpcinfo -p <target-ip>
showmount -e <target-ip>
```

Mount known export read-only; inspect UIDs/content:

```bash
sudo mkdir -p /mnt/target-nfs
sudo mount -t nfs -o ro <target-ip>:/export /mnt/target-nfs
find /mnt/target-nfs -maxdepth 2 -type f -ls
stat -c '%u:%g %A %n' /mnt/target-nfs
sudo umount /mnt/target-nfs
```

Mount fails: check export path, client allowlist, NFS version, TCP/2049. NFSv4 paths may differ. `no_root_squash` matters only with confirmed permissions.

References: [`showmount`](https://man7.org/linux/man-pages/man8/showmount.8.html) · [NFS exports](https://man7.org/linux/man-pages/man5/exports.5.html).
