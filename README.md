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
| Start Transaction    | `XA START <id>` or `START TRANSACTION` or `BEGIN` | `START TRANSACTION` or `BEGIN`
| One-Phase Commit     | `XA COMMIT <id> ONE PHASE`  | `COMMIT`

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

**Table: _.xa_recover**

This table uses the CONNECT storage engine and runs `XA RECOVER` locally. It can be used to filter and order
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

## License

Copyright: Vettabase 2026

All documentation and cheatsheets in this project are covered by the [CreativeCommons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/deed.en) license.

All code in this project is covered by the [GNU AGPL 3](https://www.gnu.org/licenses/agpl-3.0.en.html) license.

