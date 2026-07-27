-- ============================================================
-- NORTE-ERP
-- Migration: 000006_access_integrity
-- ============================================================

begin;

-- ============================================================
-- Normalize systems
-- ============================================================

create or replace function app.normalize_system_record()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.code := upper(trim(new.code));
  new.name := trim(new.name);
  new.description := nullif(trim(new.description), '');
  new.base_url := nullif(trim(new.base_url), '');
  new.icon_key := nullif(trim(new.icon_key), '');

  return new;
end;
$$;

create trigger systems_normalize_record
before insert or update on app.systems
for each row
execute function app.normalize_system_record();

-- ============================================================
-- Normalize employees
-- ============================================================

create or replace function app.normalize_employee_record()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.employee_number := app.normalize_employee_number(new.employee_number);
  new.first_name := trim(new.first_name);
  new.middle_name := nullif(trim(new.middle_name), '');
  new.paternal_last_name := nullif(trim(new.paternal_last_name), '');
  new.maternal_last_name := trim(new.maternal_last_name);
  new.institutional_email := app.normalize_email(new.institutional_email);

  return new;
end;
$$;

create trigger employees_normalize_record
before insert or update on app.employees
for each row
execute function app.normalize_employee_record();

-- ============================================================
-- Normalize roles
-- ============================================================

create or replace function app.normalize_role_record()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.code := lower(trim(new.code));
  new.name := trim(new.name);
  new.description := nullif(trim(new.description), '');

  return new;
end;
$$;

create trigger roles_normalize_record
before insert or update on app.roles
for each row
execute function app.normalize_role_record();

-- ============================================================
-- Normalize permissions
-- ============================================================

create or replace function app.normalize_permission_record()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.code := lower(trim(new.code));
  new.name := trim(new.name);
  new.description := nullif(trim(new.description), '');
  new.resource := lower(trim(new.resource));
  new.action := lower(trim(new.action));

  return new;
end;
$$;

create trigger permissions_normalize_record
before insert or update on app.permissions
for each row
execute function app.normalize_permission_record();

-- ============================================================
-- Validate role-permission system consistency
-- ============================================================

create or replace function app.validate_role_permission_system()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  role_system_id uuid;
  permission_system_id uuid;
begin
  select role.system_id
  into role_system_id
  from app.roles as role
  where role.id = new.role_id;

  select permission.system_id
  into permission_system_id
  from app.permissions as permission
  where permission.id = new.permission_id;

  if role_system_id is null then
    raise exception 'Role does not exist';
  end if;

  if permission_system_id is null then
    raise exception 'Permission does not exist';
  end if;

  if role_system_id <> permission_system_id then
    raise exception 'Role and permission must belong to the same system';
  end if;

  return new;
end;
$$;

create trigger role_permissions_validate_system
before insert or update on app.role_permissions
for each row
execute function app.validate_role_permission_system();

-- ============================================================
-- Validate employee role access
-- ============================================================

create or replace function app.validate_employee_role_access()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  assigned_role_system_id uuid;
  employee_has_access boolean;
begin
  select role.system_id
  into assigned_role_system_id
  from app.roles as role
  where role.id = new.role_id
    and role.is_active = true;

  if assigned_role_system_id is null then
    raise exception 'Role does not exist or is inactive';
  end if;

  select exists (
    select 1
    from app.employee_system_access as access
    where access.employee_id = new.employee_id
      and access.system_id = assigned_role_system_id
      and access.is_active = true
      and access.revoked_at is null
  )
  into employee_has_access;

  if employee_has_access is false then
    raise exception 'Employee must have active access to the role system';
  end if;

  return new;
end;
$$;

create trigger employee_roles_validate_access
before insert or update on app.employee_roles
for each row
execute function app.validate_employee_role_access();

-- ============================================================
-- Keep access revocation fields consistent
-- ============================================================

create or replace function app.synchronize_access_revocation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.is_active = true then
    new.revoked_at := null;
  elsif new.revoked_at is null then
    new.revoked_at := timezone('utc', now());
  end if;

  return new;
end;
$$;

create trigger employee_system_access_sync_revocation
before insert or update on app.employee_system_access
for each row
execute function app.synchronize_access_revocation();

-- ============================================================
-- Prevent active roles when system access is revoked
-- ============================================================

create or replace function app.deactivate_employee_roles_on_access_revocation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.is_active = true and new.is_active = false then
    update app.employee_roles as employee_role
    set
      is_active = false,
      updated_at = timezone('utc', now())
    from app.roles as role
    where employee_role.role_id = role.id
      and employee_role.employee_id = new.employee_id
      and role.system_id = new.system_id
      and employee_role.is_active = true;
  end if;

  return new;
end;
$$;

create trigger employee_system_access_deactivate_roles
after update of is_active on app.employee_system_access
for each row
execute function app.deactivate_employee_roles_on_access_revocation();

-- ============================================================
-- Security
-- ============================================================

revoke all on function app.normalize_system_record() from public, anon, authenticated;
revoke all on function app.normalize_employee_record() from public, anon, authenticated;
revoke all on function app.normalize_role_record() from public, anon, authenticated;
revoke all on function app.normalize_permission_record() from public, anon, authenticated;
revoke all on function app.validate_role_permission_system() from public, anon, authenticated;
revoke all on function app.validate_employee_role_access() from public, anon, authenticated;
revoke all on function app.synchronize_access_revocation() from public, anon, authenticated;
revoke all on function app.deactivate_employee_roles_on_access_revocation()
from public, anon, authenticated;

grant execute on function app.normalize_system_record() to service_role;
grant execute on function app.normalize_employee_record() to service_role;
grant execute on function app.normalize_role_record() to service_role;
grant execute on function app.normalize_permission_record() to service_role;
grant execute on function app.validate_role_permission_system() to service_role;
grant execute on function app.validate_employee_role_access() to service_role;
grant execute on function app.synchronize_access_revocation() to service_role;
grant execute on function app.deactivate_employee_roles_on_access_revocation()
to service_role;

commit;