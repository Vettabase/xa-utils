CREATE SCHEMA IF NOT EXISTS _;

CREATE OR REPLACE FUNCTION _.tpc_get_rollback_commands()
    RETURNS SETOF TEXT
    LANGUAGE plpgsql
AS $$
DECLARE
    entry RECORD;
BEGIN
    -- Loop through all prepared transactions
    FOR entry IN 
        SELECT gid FROM pg_prepared_xacts 
    LOOP
        -- Return the formatted command as a row
        RETURN NEXT format('ROLLBACK PREPARED %L;', entry.gid);
    END LOOP;
    
    RETURN;
END;
$$;

COMMENT ON FUNCTION tpc_get_rollback_commands() IS
    'Return SQL commands to manually rollback all prepared 2pc transactions'
;
