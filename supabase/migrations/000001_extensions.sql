-- ============================================================
-- NORTE-ERP
-- Migration: 000001_extensions
-- ============================================================

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";
create extension if not exists "citext";