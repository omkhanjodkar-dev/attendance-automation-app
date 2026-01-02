-- Migration: Add OTP support for Nearby Connections attendance
-- Created: 2026-01-02
-- Description: Adds session_otps table to store One-Time Passwords for proximity-based attendance

-- Create session_otps table
CREATE TABLE IF NOT EXISTS session_otps (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES active_sessions(id) ON DELETE CASCADE,
    otp_code VARCHAR(6) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_otp_code ON session_otps(otp_code);
CREATE INDEX IF NOT EXISTS idx_otp_session_id ON session_otps(session_id);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at ON session_otps(expires_at);

-- Add comment to table
COMMENT ON TABLE session_otps IS 'Stores OTP codes for Nearby Connections-based attendance verification';

-- Rollback script (run this to undo the migration):
-- DROP INDEX IF EXISTS idx_otp_expires_at;
-- DROP INDEX IF EXISTS idx_otp_session_id;
-- DROP INDEX IF EXISTS idx_otp_code;
-- DROP TABLE IF EXISTS session_otps;
