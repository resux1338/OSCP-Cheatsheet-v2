# Databases and Redis

[← Service index](service-triage.md) · [manual SQL injection](../web/manual-sqli.md)

Connect, check current identity/rights, then accessible data.

## MySQL: 3306

```bash
mysql -h <target-ip> -u <user> -p
```

```sql
SELECT USER(), CURRENT_USER(), @@version, @@secure_file_priv;
SHOW GRANTS;
SHOW DATABASES;
```

MySQL: `USER()` = supplied login; `CURRENT_USER()` = privilege account. File access needs `FILE` and allowed `secure_file_priv`.

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

PostgreSQL `\dt` covers current search path; check other schemas if blank.

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

MSSQL: use `-windows-auth` only for Windows login. [`xp_cmdshell` checks](../web/manual-sqli.md#mssql-string-context).

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

Redis: continue `SCAN` to cursor `0`; check `TYPE` before `GET`; avoid `KEYS *` on large DB.

References: [MySQL grants](https://dev.mysql.com/doc/refman/8.4/en/show-grants.html) · [PostgreSQL `psql`](https://www.postgresql.org/docs/current/app-psql.html) · [Redis `SCAN`](https://redis.io/docs/latest/commands/scan/).
