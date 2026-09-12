# Databases and Redis

[← Service index](service-triage.md) · [manual SQL injection](../web/manual-sqli.md)

Connect with a supplied or discovered credential, then inspect the current identity and accessible data before considering file or command execution.

## MySQL: 3306

```bash
mysql -h <target-ip> -u <user> -p
```

```sql
SELECT USER(), CURRENT_USER(), @@version, @@secure_file_priv;
SHOW GRANTS;
SHOW DATABASES;
```

`USER()` is the login you supplied; `CURRENT_USER()` is the account MySQL matched for privilege checks. `secure_file_priv` and the `FILE` privilege affect server-side file access.

## PostgreSQL: 5432

```bash
psql -h <target-ip> -U <user> -d <database>
```

```text
\conninfo
\l
\du
\dt
```

```sql
SELECT current_user, version();
```

`\dt` lists tables in the current search path; a blank result does not mean the server has no user tables.

## MSSQL: 1433

```bash
impacket-mssqlclient '<user>:<password>@<target-ip>' -windows-auth
```

```sql
SELECT SYSTEM_USER;
SELECT DB_NAME();
SELECT IS_SRVROLEMEMBER('sysadmin');
EXEC sp_linkedservers;
```

Windows authentication is only for a matching Windows login. If you have a SQL login, connect without `-windows-auth`. Manual `xp_cmdshell` checks and cleanup are in [manual SQL injection](../web/manual-sqli.md#mssql-string-context).

## Redis: 6379

```bash
redis-cli -h <target-ip> -p 6379
```

```text
PING
ACL WHOAMI
INFO server
SCAN 0
TYPE <selected-key>
GET <selected-string-key>
```

Continue `SCAN` with the returned cursor until it is `0`. `GET` applies to string keys; check `TYPE` first. Avoid `KEYS *` on a large instance. Record access and configuration before testing a write path.

References: [MySQL grants](https://dev.mysql.com/doc/refman/8.4/en/show-grants.html) · [PostgreSQL `psql`](https://www.postgresql.org/docs/current/app-psql.html) · [Redis `SCAN`](https://redis.io/docs/latest/commands/scan/).
