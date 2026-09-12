# Kernel and container checks

[← Linux quick reference](../03-linux-privesc.md)

Use these checks after sudo, root-run files, groups, and shares have produced no clear path. A kernel version string is a lead; distributions can backport fixes without changing the version you first notice.

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

Check the exact package build, configuration, architecture, and vendor patches before treating a CVE match as exploitable. Root inside a container is not automatically root on the host.
