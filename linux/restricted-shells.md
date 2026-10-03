# Restricted shell checks

[← Linux quick reference](../03-linux-privesc.md)

## Identify the restriction before selecting an escape

Inspect the current shell, allowed commands, PATH, and any visible wrapper policy. A restricted Bash session, a command allowlist, an SSH forced command, and a menu are different mechanisms.

```bash
printf '%s\n' "$0" "$SHELL" "$PATH"
command -v vi vim python3 awk find
```

For rbash, commands containing `/` and assignments to `PATH`/`SHELL` are explicitly restricted. Calling `/bin/ls` or exporting a new PATH is therefore not a generic escape. An allowed program may still expose command execution outside those shell checks. [GNU restricted-shell manual](https://www.gnu.org/s/bash/manual/html_node/The-Restricted-Shell.html).

## Use an observed allowed command

Try only an installed/allowed program whose relevant feature is available:

```bash
# An unrestricted editor may expose :shell or :!/bin/bash; restricted editor modes can block it.
vi
# Allowed interpreters with their command-execution feature available:
python3 -c 'import pty;pty.spawn("/bin/bash")'
awk 'BEGIN{system("/bin/bash")}'
# The current directory matches; this does not rely on a nonexistent filename.
find . -maxdepth 0 -exec /bin/bash \;
```

These examples require the outer command and supplied arguments to be permitted. An allowlist can reject them before the interpreter runs. A working PTY only improves terminal behavior; it does not add privileges. [GTFOBins find](https://gtfobins.org/gtfobins/find/), [Vim shell commands](https://vimhelp.org/various.txt.html#%3Ashell).

Check the resulting shell and identity with `printf '%s\n' "$0"` and `id`; the escaped process normally remains the same user. Exit that child to return to the original session.

SSH remote-command requests still pass through the configured login shell, forced-command wrapper, and server policy. The old Shellshock-shaped environment string is a historical, version-dependent vulnerability, not a generic restricted-shell escape. Determine the actual wrapper and available behavior instead of cycling through that string.

If a program is missing, its execution feature is disabled, or the wrapper rejects the arguments, return to the allowlist and identify a different observed capability. Changes to writable startup files/wrappers need original-state capture and a confirmed new-session trigger.
