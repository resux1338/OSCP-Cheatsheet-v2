# SUID, SGID, and file capabilities

[← Linux quick reference](../03-linux-privesc.md) · [Enumeration](enumeration.md) · [Sudo rules](sudo.md)

Record the executable, owner/group, mode or file capability, current identity, mount/namespace context, and behavior you can invoke. A normal SUID utility may deliberately expose only a constrained operation. An unusual permission is a lead until the selected action demonstrates additional access.

## Discovery and candidate validation

Run the first pass as the existing low-privileged user:

```bash
id
find / -xdev -type f -perm -4000 -exec ls -l {} \; 2>/dev/null
find / -xdev -type f -perm -2000 -exec ls -l {} \; 2>/dev/null
getcap -r /usr /opt /home 2>/dev/null
```

`-xdev` restricts the search to the starting filesystem. Inspect relevant additional mounts separately. If `getcap` is unavailable through PATH, check whether libcap tools are installed under `/usr/sbin`; absence of command output is not proof that no file capabilities exist. The recursive and namespace-display options are documented in [getcap](https://man7.org/linux/man-pages/man8/getcap.8.html).

For each promising executable, replace the illustrative path below:

```bash
candidate=/opt/tools/bash
resolved=$(readlink -f -- "$candidate")
stat -Lc '%A %a %U:%G %n' -- "$candidate"
file -- "$resolved"
namei -l -- "$resolved"
getcap -n "$resolved"
findmnt -T "$resolved" -o TARGET,FSTYPE,OPTIONS
grep -E '^(Uid|Gid|Cap(Inh|Prm|Eff|Bnd|Amb)|NoNewPrivs|Seccomp):' /proc/$$/status
```

Check permission to execute the resolved file and traverse its directories. Inspect the program's version, accepted arguments, and intended privilege handling. Use [GTFOBins](https://gtfobins.org/) for the correct SUID or capability context, rather than adapting a sudo example without checking identity behavior.

## Understand the privilege transition

| Mechanism | What successful execution can change |
| --- | --- |
| SUID executable | Effective UID becomes the file owner's UID; that owner need not be root. |
| SGID executable | Effective GID becomes the file's group; verify group access, not just UID. |
| File capabilities | Grants particular kernel privileges subject to capability-set and namespace rules. |
| Shell privilege dropping | A child shell may discard an acquired effective identity. Bash `-p` preserves it. |

Linux ignores SUID/SGID bits on interpreter scripts. `nosuid`, inherited `no_new_privs`, or tracing can suppress SUID/SGID transitions and file capabilities. Reading mode bits alone does not settle execution behavior. [execve privilege rules](https://man7.org/linux/man-pages/man2/execve.2.html). Bash describes effective-identity preservation under its [`-p` option](https://www.gnu.org/software/bash/manual/bash.html).

Do not diagnose a privilege transition solely through `strace` or a debugger: tracing can alter the transition you are investigating. Static inspection and a benign untraced identity proof are useful complements.

## Workflow 1: root-owned SUID Bash

**Observed prerequisites:** `/opt/tools/bash` is a real compatible Bash executable, owned by UID 0, with SUID set and executable access for the current user. Its filesystem permits the transition, the calling process has `NoNewPrivs: 0`, and the executable has no additional restrictions that invalidate the route. Do not add SUID to a system binary to manufacture this prerequisite.

Confirm the file and compare real/effective identities:

```bash
id
stat -Lc '%A %a %U:%G %n' /opt/tools/bash
findmnt -T /opt/tools/bash -o TARGET,FSTYPE,OPTIONS
/opt/tools/bash --noprofile --norc -p -c \
  'printf "real UID=%s effective UID=%s\n" "$UID" "$EUID"; /usr/bin/id'
```

An example result is `real UID=1000 effective UID=0`, followed by `id` output containing `euid=0(root)`. Keeping the real UID unchanged is expected for this SUID transition. `-p` preserves the acquired effective identity; it does not grant privilege to an ordinary Bash executable. The process exits after printing its proof, so no shell is left running and no file needs restoration. [GTFOBins Bash SUID behavior](https://gtfobins.org/gtfobins/bash/).

If the effective UID remains the original user, recheck the executed file, owner, mount flags, and caller's `NoNewPrivs`. If execution fails before a proof, check architecture, loader, directory traversal, and execute permissions. Avoid concluding that a shell is privileged from its prompt alone.

## Workflow 2: Python with effective CAP_SETUID

**Observed prerequisites:** the resolved executable `/opt/tools/python3` has `cap_setuid=ep` (some tools display equivalent notation with `+ep`), the capability is effective when it runs, and UID 0 is meaningful in its governing user namespace. It supports the Python `os` functions used below.

```bash
id
getcap -n /opt/tools/python3
findmnt -T /opt/tools/python3 -o TARGET,FSTYPE,OPTIONS
/opt/tools/python3 -c 'import os; print("before:", os.getuid(), os.geteuid(), flush=True); os.setuid(0); print("after:", os.getuid(), os.geteuid(), flush=True); os.execl("/usr/bin/id", "id")'
```

Expected output starts with the current user's IDs, then prints `after: 0 0`; the replaced process reports `uid=0(root)`. The identity change happens inside this child process; the original shell remains unchanged. No file or permission is changed, and the proof process exits after `id`.

`CAP_SETUID` permits UID manipulation subject to namespace rules; Python exposes `setuid` and `execl` through `os`. [Linux capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html), [Python OS functions](https://docs.python.org/3/library/os.html#os.setuid).

An `Operation not permitted` result means the required privilege did not apply to this operation. Check the resolved file, effective/bounding capability sets, `nosuid`, `no_new_privs`, and user-namespace UID mapping. An interpreter with only a permitted capability may need to enable it first; the command above assumes the effective bit, and must not be generalized to every capability suffix.

## Choose a useful action for the capability

| Capability | Relevant behavior to investigate |
| --- | --- |
| `CAP_SETUID` | Change UID within the applicable user namespace. |
| `CAP_SETGID` | Change group identities or supplementary groups; establish the resulting file/service access. |
| `CAP_DAC_READ_SEARCH` | Read files and traverse directories despite discretionary checks; this does not grant writes. |
| `CAP_DAC_OVERRIDE` | Bypass many discretionary read/write checks; other security mechanisms still apply. |
| `CAP_SYS_PTRACE` | Process inspection/control where namespace and security-policy requirements are satisfied. |
| `CAP_SYS_ADMIN` | Broad, namespace-dependent operations; inspect the actual operation and container context. |

These are kernel privileges, not interchangeable root-shell grants. For a file-read capability, the read must occur in the process that holds it; starting an ordinary `cat` child does not generally carry the capability forward. Confirm the effective set and actual protected-file access before claiming the route. [Capability definitions and execution transitions](https://man7.org/linux/man-pages/man7/capabilities.7.html).

## Diagnose misleading leads

| Finding or result | Interpretation / next check |
| --- | --- |
| SUID bit on a script | Linux does not honor the script's SUID bit; find the privileged interpreter or caller instead. |
| SUID owner is another user | Any acquired identity belongs to that owner; inspect its access as a separate step. |
| SUID utility runs, but its child is unprivileged | Determine whether the utility or selected shell drops effective IDs. |
| `NoNewPrivs: 1` | Future execution cannot gain privilege through SUID/SGID or file capabilities. |
| `nosuid` on the candidate's mount | File-derived privilege is suppressed on that mount. |
| Capability shown, but action denied | Check effective/bounding sets, operation requirements, namespace, and MAC/security restrictions. |
| UID 0 inside a container | Inspect mapping and mounts; this proves root in that context, not host-root access. |
| No result in the first search | Investigate additional mounts, unreadable directories, and the availability of capability tools. |

For the `no_new_privs` guarantee, see the [kernel interface documentation](https://man7.org/linux/man-pages/man2/PR_SET_NO_NEW_PRIVS.2const.html). For namespace/daemon context, continue with [groups and containers](groups-and-nfs.md).

## Deeper inspection and restoration

For a custom privileged binary, inspect `file`, documented arguments, strings, called executables, and configuration paths. A string naming a command or library is a lead; it does not establish that the privileged execution reaches it. Investigate writable helpers and parent directories on the [root-run dependency page](root-run.md).

For a shared-library lead, `readelf -d /path/to/binary` shows dependencies and RPATH/RUNPATH entries. Evaluate the actual selected library and whether its location is writable. Secure execution changes environment-based library lookup; simply setting `LD_LIBRARY_PATH` or `LD_PRELOAD` is insufficient for ordinary SUID execution. [Dynamic-linker search and secure-execution rules](https://man7.org/linux/man-pages/man8/ld.so.8.html).

The two worked proofs require no system modifications. If a separate technique changes a helper, configuration, permissions, or extended attributes, capture those values first and restore the exact changes after verification. Rewriting/copying a privileged file can alter its mode or capability xattr; a contents-only backup is insufficient. Check restored contents, ownership, mode, ACLs, and `getcap` output as applicable.

## Review and validation

Sources reviewed on 2 October 2026. Bash argument/identity behavior and a child-process `no_new_privs` fixture were checked locally with Bash 5.2.37, GNU findutils 4.10.0, Python 3.13.5, and util-linux 2.41.5. `getcap` options were checked against installed help and the upstream manual. No SUID/capability fixture was granted root privileges, so the elevated worked results remain source-verified examples pending validation against the observed host conditions.
