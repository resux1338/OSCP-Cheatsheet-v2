# Privileged file-write paths

[← Linux quick reference](../03-linux-privesc.md)

## Establish exactly what the primitive grants

Record the privileged caller, controllable source/destination, overwrite versus append behavior, symlink handling, accepted path boundaries, and output ownership/mode. Test with a harmless lab destination before changing an authentication or scheduled-execution file.

| Candidate destination | Additional prerequisite |
| --- | --- |
| sudoers include | Active include directory, accepted filename, owner/mode, valid syntax, and a confirmed restore/delete route |
| passwd/shadow | Correct record format and the actual authentication stack; preserve existing entries |
| cron configuration | System versus user-crontab format, accepted ownership/mode, privileged consumer, and schedule |
| SSH authorized keys | Correct account/home/key path, accepted metadata, and server login policy |

An empty password field is ordinarily rejected by `pam_unix` unless the relevant service enables `nullok`. Removing a passwd `x` field does not establish successful root authentication. [Linux-PAM authentication semantics](https://github.com/linux-pam/linux-pam/blob/master/modules/pam_unix/pam_unix.8.xml).

## Symlink-following writer

Observed pattern: an already-authorized privileged tool writes source bytes to a caller-selected destination and follows a destination symlink. Confirm the actual implementation; many tools replace the link, refuse it, or write through a different path.

In a disposable lab where the tool can create an accepted sudoers include and restoration is available, a narrowly scoped identity rule is sufficient:

```bash
printf '%s\n' 'student ALL=(root) NOPASSWD: /usr/bin/id' > payload
chmod 440 payload
ln -s /etc/sudoers.d/lab-proof dst_link
```

Use the exact observed writer to copy `payload` to `dst_link`. Changing the **source** mode does not guarantee the destination's mode/owner: inspect what the tool creates/preserves. `0440` is the conventional sudoers default, with configurable expected metadata. The include must be enabled and the name accepted. Validate with `visudo -c` through an available authorized context, then `sudo -u root /usr/bin/id`; only `uid=0` output establishes the identity result. [sudoers configuration](https://github.com/sudo-project/sudo/blob/main/docs/sudoers.man.in).

Preserve any preexisting destination first; do not overwrite another rule. After the proof, restore original bytes/metadata or remove the newly created include through the confirmed privileged cleanup route. Remove your local symlink/payload. The identity-only rule deliberately does not supply a privileged deletion command, so establish cleanup access before installing it.

## Archives: distinguish storing, extracting, and dereferencing

```bash
ln -s /root/lab-evidence.txt leak
zip --symlinks lab-links.zip leak
```

This ZIP stores a symlink. It does not contain the protected target's bytes and extraction alone does not prove arbitrary read. A separate privileged step must follow the link and return readable data. Conversely, a destination-side link can matter if the extractor follows it during a write; the exact member order and existing filesystem state matter. [Info-ZIP distributed manual](https://manpages.debian.org/bookworm/zip/zip.1.en.html).

Reproduce the actual extractor/version with harmless files in a separate temporary tree. Record whether it creates a link, follows one, rejects it, or replaces it with a regular file. Test destination boundaries and member ordering. Rejecting `../` names does not settle symlink behavior. Remove only the fixture/archive/link created for the test and verify that no privileged target was altered.
