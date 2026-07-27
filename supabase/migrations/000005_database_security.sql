-- ============================================================
-- NORTE-ERP
-- Migration: 000005_database_security
-- ============================================================

begin;

-- ============================================================
-- Enable Row Level Security
-- ============================================================

alter table app.systems enable row level security;
alter table app.employees enable row level security;
alter table app.roles enable row level security;
alter table app.permissions enable row level security;
alter table app.role_permissions enable row level security;
alter table app.employee_system_access enable row level security;
alter table app.employee_roles enable row level security;
alter table audit.logs enable row level security;

-- ============================================================
-- Revoke direct access
-- ============================================================

revoke all on all tables in schema app from public;
revoke all on all tables in schema app from anon;
revoke all on all tables in schema app from authenticated;

revoke all on all sequences in schema app from public;
revoke all on all sequences in schema app from anon;
revoke all on all sequences in schema app from authenticated;

revoke all on all functions in schema app from public;
revoke all on all functions in schema app from anon;
revoke all on all functions in schema app from authenticated;

revoke all on all tables in schema audit from public;
revoke all on all tables in schema audit from anon;
revoke all on all tables in schema audit from authenticated;

revoke all on all sequences in schema audit from public;
revoke all on all sequences in schema audit from anon;
revoke all on all sequences in schema audit from authenticated;

revoke all on all functions in schema audit from public;
revoke all on all functions in schema audit from anon;
revoke all on all functions in schema audit from authenticated;

-- ============================================================
-- Service role access
-- ============================================================

grant usage on schema app to service_role;
grant usage on schema audit to service_role;
grant usage on schema private to service_role;

grant all privileges on all tables in schema app to service_role;
grant all privileges on all sequences in schema app to service_role;
grant execute on all functions in schema app to service_role;

grant select, insert on audit.logs to service_role;
grant usage, select on all sequences in schema audit to service_role;
grant execute on all functions in schema audit to service_role;

-- ============================================================
-- Default privileges for future objects
-- ============================================================

alter default privileges in schema app
revoke all on tables from public, anon, authenticated;

alter default privileges in schema app
revoke all on sequences from public, anon, authenticated;

alter default privileges in schema app
revoke execute on functions from public, anon, authenticated;

alter default privileges in schema app
grant all privileges on tables to service_role;

alter default privileges in schema app
grant all privileges on sequences to service_role;

alter default privileges in schema app
grant execute on functions to service_role;

alter default privileges in schema audit
revoke all on tables from public, anon, authenticated;

alter default privileges in schema audit
revoke all on sequences from public, anon, authenticated;

alter default privileges in schema audit
revoke execute on functions from public, anon, authenticated;

-- ============================================================
-- Current employee helper
-- ============================================================

create or replace function app.current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select employee.id
  from app.employees as employee
  where employee.auth_user_id = auth.uid()
    and employee.is_active = true
    and employee.deleted_at is null
  limit 1;
$$;

revoke all on function app.current_employee_id() from public;
revoke all on function app.current_employee_id() from anon;
revoke all on function app.current_employee_id() from authenticated;

grant execute on function app.current_employee_id() to service_role;

-- ============================================================
-- Employee system access helper
-- ============================================================

create or replace function app.employee_has_system_access(
  target_employee_id uuid,
  target_system_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from app.employee_system_access as access
    inner join app.employees as employee
      on employee.id = access.employee_id
    inner join app.systems as system
      on system.id = access.system_id
    where access.employee_id = target_employee_id
      and access.system_id = target_system_id
      and access.is_active = true
      and access.revoked_at is null
      and employee.is_active = true
      and employee.deleted_at is null
      and system.is_active = true
  );
$$;

revoke all on function app.employee_has_system_access(uuid, uuid)
from public, anon, authenticated;

grant execute on function app.employee_has_system_access(uuid, uuid)
to service_role;

-- ============================================================
-- Employee permission helper
-- ============================================================

create or replace function app.employee_has_permission(
  target_employee_id uuid,
  target_permission_code text,
  target_system_code text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from app.employee_roles as employee_role
    inner join app.roles as role
      on role.id = employee_role.role_id
    inner join app.systems as system
      on system.id = role.system_id
    inner join app.role_permissions as role_permission
      on role_permission.role_id = role.id
    inner join app.permissions as permission
      on permission.id = role_permission.permission_id
    inner join app.employee_system_access as access
      on access.employee_id = employee_role.employee_id
      and access.system_id = system.id
    inner join app.employees as employee
      on employee.id = employee_role.employee_id
    where employee_role.employee_id = target_employee_id
      and upper(trim(system.code)) = upper(trim(target_system_code))
      and lower(trim(permission.code)) = lower(trim(target_permission_code))
      and employee_role.is_active = true
      and (
        employee_role.expires_at is null
        or employee_role.expires_at > timezone('utc', now())
      )
      and role.is_active = true
      and permission.is_active = true
      and system.is_active = true
      and access.is_active = true
      and access.revoked_at is null
      and employee.is_active = true
      and employee.deleted_at is null
  );
$$;

revoke all on function app.employee_has_permission(uuid, text, text)
from public, anon, authenticated;

grant execute on function app.employee_has_permission(uuid, text, text)
to service_role;

commit;