-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 01_create_database.sql
-- Description: Creates the operational database and sets up environment
--              configurations for PostgreSQL 14+.
-- ============================================================================

SET timezone = 'UTC';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

COMMENT ON DATABASE current_database() IS 'Textile Production Waste, Defect & Machine Intelligence System Database';
