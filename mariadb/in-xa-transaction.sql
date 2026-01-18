CREATE SCHEMA IF NOT EXISTS _;

DELIMITER ||

CREATE OR REPLACE FUNCTION _.in_xa_transaction(connection_id BIGINT UNSIGNED DEFAULT NULL)
    RETURNS BOOL
    COMMENT 'Return TRUE if the specified connection exists and started an XA transaction, regardless we already accessed row or not'
BEGIN
    DECLARE last_sql TEXT DEFAULT NULL;
    IF connection_id IS NULL THEN
        SET connection_id := CONNECTION_ID();
    END IF;
    SET last_sql := (
        SELECT SQL_TEXT
            FROM performance_schema.events_statements_history
            WHERE
                THREAD_ID = (
                    SELECT THREAD_ID
                    FROM performance_schema.threads
                    WHERE PROCESSLIST_ID = connection_id
                )
                AND SQL_TEXT LIKE 'XA%'
                AND MYSQL_ERRNO = 0
            ORDER BY EVENT_ID DESC
            LIMIT 1
    );
    IF last_sql IS NULL THEN
        RETURN FALSE;
    END IF;
    
    RETURN NOT (last_sql LIKE 'XA%COMMIT%' OR last_sql LIKE 'XA%ROLLBACK%');
END;
||

DELIMITER ;
