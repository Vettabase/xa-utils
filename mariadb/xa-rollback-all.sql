CREATE SCHEMA IF NOT EXISTS _;

-- A user for CONNECT engine's local connections
CREATE OR REPLACE USER 'connect'@'localhost' IDENTIFIED BY PASSWORD '*14E65567ABDB5135D0CFD9A70B3032C179A49EE7';
GRANT SUPER ON *.* TO 'connect'@'localhost';
GRANT SELECT ON _.* TO 'connect'@'localhost';

CREATE OR REPLACE TABLE `_`.`xa_recover`
	ENGINE = CONNECT
	TABLE_TYPE = MYSQL
	SRCDEF = 'XA RECOVER FORMAT = \'SQL\''
	CONNECTION = 'mysql://connect:secret@localhost/_'
	COMMENT 'Useful because XA RECOVER doesnt support filtering, ordering, or cursors'
;

DELIMITER ||

CREATE OR REPLACE PROCEDURE _.xa_rollback_all()
    MODIFIES SQL DATA
    COMMENT 'Rollback all prepared XA transactions'
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE xid VARCHAR(255);
    
    -- We only need the 'data' column, which contains the quoted SQL literal
    DECLARE cur CURSOR FOR 
        SELECT data FROM _.xa_recover
    ;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    -- XA ROLLBACK produces an error, but we'll ignore it
    DECLARE CONTINUE HANDLER FOR SQLSTATE 'XA100' BEGIN END;

    OPEN cur;
    trx_loop: LOOP
        FETCH cur INTO xid;
        
        IF done THEN
            LEAVE trx_loop;
        END IF;
        
        -- EXECUTE IMMEDIATE handles the PREPARE/EXECUTE/DEALLOCATE cycle in one line
        EXECUTE IMMEDIATE CONCAT('XA ROLLBACK ', xid);
    END LOOP;
    CLOSE cur;
END
||

DELIMITER ;

