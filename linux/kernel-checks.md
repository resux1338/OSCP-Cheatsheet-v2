# Kernel and container checks

[← Linux quick reference](../03-linux-privesc.md)

After sudo/files/groups/shares: check exact kernel package, not just version string (backports).

```bash
uname -a
uname -r
cat /etc/os-release
dpkg-query -W 2>/dev/null
rpm -qa 2>/dev/null
sudo -V | head -1
```

```bash
getcap -r / 2>/dev/null
getpcaps $$ 2>/dev/null
lsns
cat /proc/1/cgroup
test -f /.dockerenv && echo docker
ls -lah /var/run/docker.sock /run/containerd/containerd.sock 2>/dev/null
```

Match package build, config, architecture, and patches. Container root ≠ host root.
