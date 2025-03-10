\c healthcare_db

-- Disable foreign key constraints and triggers
SET session_replication_role = 'replica';

-- Delete all data and reset all identities in tables within the healthcare schema
DO $$
DECLARE
    table_name TEXT;
BEGIN
    FOR table_name IN
        (SELECT tablename FROM pg_tables WHERE schemaname = 'healthcare')
    LOOP
        EXECUTE format('TRUNCATE TABLE healthcare.%I RESTART IDENTITY CASCADE', table_name);
    END LOOP;
END $$;

-- Re-enable foreign key constraints and triggers
SET session_replication_role = 'origin';

