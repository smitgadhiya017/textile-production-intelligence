-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 01_create_database.sql
-- Description: Creates the operational database, dedicated schema, and sets up
--              environment configurations for PostgreSQL 14+.
-- ============================================================================

-- Create Database (Run as superuser / postgres admin if creating fresh database)
-- CREATE DATABASE textile_intelligence_db
--     WITH 
--     OWNER = postgres
--     ENCODING = 'UTF8'
--     LC_COLLATE = 'English_United States.1252'
--     LC_CTYPE = 'English_United States.1252'
--     TABLESPACE = pg_default
--     CONNECTION LIMIT = -1;

-- Connect to database
-- \c textile_intelligence_db;

-- Set timezone to UTC for consistent multi-plant timestamp handling
SET timezone = 'UTC';

-- Create extension for UUID generation if needed in the future
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create dedicated analytical and operational schema if desired
-- CREATE SCHEMA IF NOT EXISTS textile_ops;
-- SET search_path TO textile_ops, public;

COMMENT ON DATABASE current_database() IS 'Textile Production Waste, Defect & Machine Intelligence System Database';
