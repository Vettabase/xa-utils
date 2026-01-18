# xa-utils
Cheatsheets and utilities for XA transactions.

Currently all the contents refer to MariaDB and PostgreSQL. We might add more DBMSs.

## MariaDB and PostgreSQL Cheatsheets

**Transaction id formats**

MariaDB transaction id formats:

- `'string', 'string', int` (eg: `'trx229', '.db1', 1`)
- `'string', 'string'` (eg: `'trx229', '.db1'`)
- `'string'` (eg: `'trx229'`)

PostgreSQL transaction id format: `'any string'`

### Two-phase transactions

| Action               | MariaDB (XA Standard)       | PostgreSQL (Native 2pc)
| -------------------- | --------------------------- | -----------------------
| Start Transaction    | `XA START <id>`             | `START TRANSACTION` or `BEGIN`
| End Work Phase       | `XA END <id>`               | (not available)
| Prepare Phase        | `XA PREPARE <id>`           | `PREPARE TRANSACTION '<id>'`
| Commit (2nd Phase)   | `XA COMMIT <id>`            | `COMMIT PREPARED '<id>'`
| Rollback             | `XA ROLLBACK <id>`          | `ROLLBACK` or `ROLLBACK PREPARED '<id>'`

### One-phase transactions

| Action               | MariaDB (XA Standard)       | PostgreSQL (Native 2pc)
| -------------------- | --------------------------- | -----------------------
| Start Transaction    | `XA START <id>`             | `START TRANSACTION` or `BEGIN`
| One-Phase Commit     | `XA COMMIT <id> ONE PHASE`  | `COMMIT`

MariaDB also supports regular transactional commands `START TRANSACTION`, `COMMIT`,
and `ROLLBACK`. It also supports `BEGIN` as a synonym for `START TRANSACTIONS`, but
it won't work in procedural SQL.

### Recovery

**MariaDB**

```
> XA RECOVER FORMAT = 'SQL';
+----------+--------------+--------------+-----------------+
| formatID | gtrid_length | bqual_length | data            |
+----------+--------------+--------------+-----------------+
|        1 |           13 |            0 | 'Transaction 1' |
|        1 |           11 |            0 | 'xxx-xxx-xxx'   |
+----------+--------------+--------------+-----------------+
> XA COMMIT <id>;
> XA ROLLBACK <id>;
```

**PostgreSQL**

```
> SELECT gid, prepared, owner, database  FROM pg_prepared_xacts;
 transaction |                 gid                  |           prepared            |  owner   | database 
-------------+--------------------------------------+-------------------------------+----------+----------
         769 | 019badbc-bb6b-7eb0-b5ac-439ade362710 | 2026-01-15 22:50:16.098882+00 | postgres | postgres
         771 | trx2                                 | 2026-01-15 22:51:27.578579+00 | postgres | postgres
> COMMIT PREPARED '<id>';
> ROLLBACK PREPARED '<id>'
```

## Utils

The source code of the following utilities can be found in the `mariadb` and `postgresql` directories.
It's meant to explain how to do things, or even to be used in your system, but it might require some
manual change. No effort is made to make the code ready to use as-is.

### MariaDB

**View: _.xa_engines**

A subset of `information_schema.ENGINES` containing storage engines that support XA transactions.

**Table: _.xa_recover**

This table uses the [CONNECT](https://mariadb.com/docs/server/server-usage/storage-engines/connect/introduction-to-the-connect-engine)
storage engine to run `XA RECOVER` locally and return its results. It can be used to filter and order
the results. Also, `XA RECOVER` can't be used directly in stored procedures, because cursors only work
with `SELECT`.

**Stored procedure: _.xa_rollback_all()**

Usage:

```
> XA RECOVER;
+----------+--------------+--------------+------+
| formatID | gtrid_length | bqual_length | data |
+----------+--------------+--------------+------+
|        1 |            4 |            0 | trx0 |
|        1 |            4 |            0 | trx3 |
+----------+--------------+--------------+------+
> CALL _.xa_rollback_all();
> XA RECOVER;
```

Intended use: after a database restart, but before accepting client connections, rollback all prepared
transactions.

**Stored function: _.in_xa_transaction([connection_id])**

MariaDB system tables don't distinguish regular transactions from XA transactions.
`in_xa_transaction()` looks for the last XA command run by the specified connection (the current connection
by default). If it's anything other than `XA COMMIT` or `XA ROLLBACK`, it assumes that an XA transaction is
in progress. Note that it doesn't check if the connection is active, so the transaction might not be in
progress. If in doubt, you'll have to check the processlist.

Similarly to `in_transaction`, this function returns 1 even if the XA transaction didn't access any data.
In this case, though, the `information_schema.innodb_trx` table won't contain a matching row.

Requirements:

- `performance_schema=1`;
- `UPDATE performance_schema.setup_consumers SET ENABLED = 'YES' WHERE NAME LIKE 'events\_statements%';`
- A sufficiently high `performance_schema_events_statements_history_size`.

Usage:

```
-- does the current connection have an active XA transaction?
SELECT in_xa_transaction();
-- does connection with id 24 have an active XA connection?
SELECT in_xa_transaction(24);
```

### PostgreSQL

**Stored function: _.tpc_get_rollback_commands()**

Usage:

```
=# SELECT _.tpc_get_rollback_commands();
    tpc_get_rollback_commands    
---------------------------------
 ROLLBACK PREPARED 'trx3';
 ROLLBACK PREPARED 'trx2';
 ROLLBACK PREPARED 'empty-pg-1';
 ROLLBACK PREPARED 'empty-pg-2';
```

Intended use: after a database restart, but before accepting client connections, rollback all prepared
transactions.

PostgreSQL doesn't support running `ROLLBACK` or `COMMIT` via `EXECUTE`, so you'll have to use this function
to print the SQL statements, and then copy and run them manually.

## License

Copyright: Vettabase 2026

All documentation and cheatsheets in this project are covered by the [CreativeCommons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/deed.en) license.

All code in this project is covered by the [GNU AGPL 3](https://www.gnu.org/licenses/agpl-3.0.en.html) license.

