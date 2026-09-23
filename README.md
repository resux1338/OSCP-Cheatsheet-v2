# OSCP / OSCP+ Cheatsheet

Offline OSCP command lookup. Check the current [OffSec exam guide](https://help.offsec.com/hc/en-us/articles/360040165632-OSCP-Exam-Guide) before the exam.

Got a shell or domain credential? Check the low-hanging fruit first:

| Access | First enumeration pass |
| --- | --- |
| Domain credential or domain-joined host | [Active Directory enumeration](ad/active-directory-enum.md) |
| Windows shell | [Windows host enumeration](windows/windows-host-enum.md) |
| Linux shell | [Linux enumeration](linux/linux-enum.md) |

Pick a phase:

| Phase | Quick reference |
| --- | --- |
| Methodology / assessment flow | [00-methodology.md](00-methodology.md) |
| Recon and enumeration | [01-recon.md](01-recon.md) |
| Foothold, shells, and web | [02-foothold.md](02-foothold.md) |
| Linux privilege escalation | [03-linux-privesc.md](03-linux-privesc.md) |
| Windows privilege escalation | [04-windows-privesc.md](04-windows-privesc.md) |
| Active Directory | [05-active-directory.md](05-active-directory.md) |
| Pivoting and tunneling | [06-pivoting.md](06-pivoting.md) |
| Password attacks and cracking | [07-password-attacks.md](07-password-attacks.md) |

Replace `<TARGET-IP>` and `<KALI-IP>`; check local tool help for version-specific flags.

Read-only helpers are in [scripts/](scripts/README.md).
