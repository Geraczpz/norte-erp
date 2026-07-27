-- ============================================================
-- NORTE-ERP
-- Migration: 000011_authentication_identity_integrity
-- ============================================================

begin;

-- ============================================================
-- Validate employee and Supabase Auth relationship
-- ============================================================

create or replace function private.validate_employee_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  stored_auth_email text;
  stored_technical_email text;
begin
  if new.auth_user_id is null then
    return new;
  end if;

  select lower(trim(auth_user.email))
  into stored_auth_email
  from auth.users as auth_user
  where auth_user.id = new.auth_user_id;

  if stored_auth_email is null then
    raise exception
      'Supabase Auth user does not exist or has no email';
  end if;

  select identity.technical_email
  into stored_technical_email
  from private.authentication_identities as identity
  where identity.employee_id = new.id;

  if stored_technical_email is null then
    raise exception
      'Employee authentication identity does not exist';
  end if;

  if stored_auth_email <> stored_technical_email then
    raise exception
      'Supabase Auth email does not match employee technical email';
  end if;

  return new;
end;
$$;

create trigger employees_validate_auth_user
before insert or update of auth_user_id
on app.employees
for each row
when (new.auth_user_id is not null)
execute function private.validate_employee_auth_user();

-- ============================================================
-- Synchronize employee data with private identity
-- ============================================================

create or replace function private.synchronize_employee_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.authentication_identities
  set
    employee_number = new.employee_number,
    auth_user_id = new.auth_user_id,
    updated_at = timezone('utc', now())
  where employee_id = new.id;

  return new;
end;
$$;

create trigger employees_synchronize_authentication_identity
after update of employee_number, auth_user_id
on app.employees
for each row
when (
  old.employee_number is distinct from new.employee_number
  or old.auth_user_id is distinct from new.auth_user_id
)
execute function private.synchronize_employee_identity();

-- ============================================================
-- Prevent changing identity ownership
-- ============================================================

create or replace function private.prevent_identity_employee_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.employee_id is distinct from new.employee_id then
    raise exception
      'Authentication identity cannot be transferred to another employee';
  end if;

  return new;
end;
$$;

create trigger authentication_identities_prevent_employee_change
before update of employee_id
on private.authentication_identities
for each row
execute function private.prevent_identity_employee_change();

-- ============================================================
-- Prevent unlinking identity while employee remains linked
-- ============================================================

create or replace function private.validate_identity_auth_unlink()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  employee_auth_user_id uuid;
begin
  if old.auth_user_id is not null
    and new.auth_user_id is null then

    select employee.auth_user_id
    into employee_auth_user_id
    from app.employees as employee
    where employee.id = new.employee_id;

    if employee_auth_user_id is not null then
      raise exception
        'Employee must be unlinked before authentication identity';
    end if;
  end if;

  return new;
end;
$$;

create trigger authentication_identities_validate_auth_unlink
before update of auth_user_id
on private.authentication_identities
for each row
execute function private.validate_identity_auth_unlink();

-- ============================================================
-- Unlink employee from Supabase Auth
-- ============================================================

create or replace function private.unlink_employee_auth_user(
  target_employee_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from app.employees as employee
    where employee.id = target_employee_id
      and employee.deleted_at is null
  ) then
    raise exception 'Employee does not exist or has been deleted';
  end if;

  update app.employees
  set auth_user_id = null
  where id = target_employee_id;

  update private.authentication_identities
  set auth_user_id = null
  where employee_id = target_employee_id;
end;
$$;

-- ============================================================
-- Security
-- ============================================================

revoke all on function private.validate_employee_auth_user()
from public, anon, authenticated;

revoke all on function private.synchronize_employee_identity()
from public, anon, authenticated;

revoke all on function private.prevent_identity_employee_change()
from public, anon, authenticated;

revoke all on function private.validate_identity_auth_unlink()
from public, anon, authenticated;

revoke all on function private.unlink_employee_auth_user(uuid)
from public, anon, authenticated;

grant execute on function private.validate_employee_auth_user()
to service_role;

grant execute on function private.synchronize_employee_identity()
to service_role;

grant execute on function private.prevent_identity_employee_change()
to service_role;

grant execute on function private.validate_identity_auth_unlink()
to service_role;

grant execute on function private.unlink_employee_auth_user(uuid)
to service_role;

commit;