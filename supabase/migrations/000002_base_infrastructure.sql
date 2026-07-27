-- ============================================================
-- NORTE-ERP
-- Migration: 000002_base_infrastructure
-- ============================================================

begin;

-- ============================================================
-- Schemas
-- ============================================================

create schema if not exists app;
create schema if not exists audit;
create schema if not exists private;

-- ============================================================
-- Permissions
-- ============================================================

revoke all on schema private from public;
revoke all on schema audit from public;

grant usage on schema app to authenticated;
grant usage on schema app to service_role;

grant usage on schema audit to service_role;
grant usage on schema private to service_role;

-- ============================================================
-- Updated timestamp function
-- ============================================================

create or replace function app.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- ============================================================
-- Employee number normalization
-- ============================================================

create or replace function app.normalize_employee_number(
  employee_number text
)
returns text
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select upper(trim(employee_number));
$$;

-- ============================================================
-- Email normalization
-- ============================================================

create or replace function app.normalize_email(
  email_address text
)
returns text
language sql
immutable
strict
security invoker
set search_path = ''
as $$
select lower(trim(email_address));
$$;

-- ============================================================
-- Current authenticated user
-- ============================================================

create or replace function app.current_auth_user_id()
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select auth.uid();
$$;

-- ============================================================
-- UUID validation
-- ============================================================

create or replace function app.is_valid_uuid(
  value text
)
returns boolean
language plpgsql
immutable
strict
security invoker
set search_path = ''
as $$
begin
  perform value::uuid;
  return true;
exception
  when invalid_text_representation then
    return false;
end;
$$;

-- ============================================================
-- Prevent direct audit mutation
-- ============================================================

create or replace function audit.prevent_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'Audit records cannot be updated or deleted';
end;
$$;

commit;