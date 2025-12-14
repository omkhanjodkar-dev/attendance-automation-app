-- Session-Based Attendance Prevention - Database Migration
-- Run this SQL script on your PostgreSQL database (Neon or Render)

-- Step 1: Add session_id column to attendance_records table
ALTER TABLE attendance_records 
ADD COLUMN IF NOT EXISTS session_id INTEGER;

-- Step 2: Add foreign key constraint
ALTER TABLE attendance_records 
ADD CONSTRAINT fk_session 
FOREIGN KEY (session_id) 
REFERENCES active_sessions(id) 
ON DELETE CASCADE;

-- Step 3: Add unique constraint to prevent duplicate attendance
ALTER TABLE attendance_records 
ADD CONSTRAINT unique_attendance_per_session 
UNIQUE (session_id, username);

-- Step 4: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_attendance_session ON attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_attendance_username ON attendance_records(username);

-- VERIFICATION QUERY
-- Run this to check if the changes were applied correctly:
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'attendance_records';

-- Expected output should include:
-- session_id | integer | YES
