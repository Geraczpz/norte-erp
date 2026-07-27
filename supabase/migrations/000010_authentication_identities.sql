-- ============================================================
-- NORTE-ERP
-- Migration: 000010_authentication_identities
-- ============================================================

begin;

-- ============================================================
-- Private authentication identities
-- ============================================================

create table private.authentication_identities (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null
    references app.employees(id)
    on delete cascade,
  auth_user_id uuid
    references auth.users(id)
    on delete cascade,
  employee_number text not null,
  technical_email text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint authentication_identities_employee_unique
    unique (employee_id),

  constraint authentication_identities_auth_user_unique
    unique (auth_user_id),

  constraint authentication_identities_employee_number_unique
    unique (employee_number),

  constraint authentication_identities_technical_email_unique
    unique (technical_email),

  constraint authentication_identities_employee_number_not_blank
    check (length(trim(employee_number)) > 0),

  constraint authentication_identities_technical_email_not_blank
    check (length(trim(technical_email)) > 0),

  constraint authentication_identities_technical_email_format
    check (
      technical_email ~*
      '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    )
);

create index authentication_identities_employee_idx
  on private.authentication_identities (employee_id);

create index authentication_identities_auth_user_idx
  on private.authentication_identities (auth_user_id)
  where auth_user_id is not null;

create index authentication_identities_employee_number_idx
  on private.authentication_identities (employee_number);

-- ============================================================
-- Normalize authentication identity
-- ============================================================

create or replace function private.normalize_authentication_identity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.employee_number :=
    app.normalize_employee_number(new.employee_number);

  new.technical_email :=
    lower(trim(new.technical_email));

  return new;
end;
$$;

create trigger authentication_identities_normalize
before insert or update on private.authentication_identities
for each row
execute function private.normalize_authentication_identity();

-- ============================================================
-- Updated timestamp
-- ============================================================

create trigger authentication_identities_set_updated_at
before update on private.authentication_identities
for each row
execute function app.set_updated_at();

-- ============================================================
-- Validate employee identity consistency
-- ============================================================

create or replace function private.validate_authentication_identity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  stored_employee_number text;
  stored_auth_user_id uuid;
begin
  select
    employee.employee_number,
    employee.auth_user_id
  into
    stored_employee_number,
    stored_auth_user_id
  from app.employees as employee
  where employee.id = new.employee_id
    and employee.deleted_at is null;

  if stored_employee_number is null then
    raise exception 'Employee does not exist or has been deleted';
  end if;

  if stored_employee_number <> new.employee_number then
    raise exception
      'Authentication employee number must match employee record';
  end if;

  if stored_auth_user_id is not null
    and new.auth_user_id is distinct from stored_auth_user_id then
    raise exception
      'Authentication user ID must match employee record';
  end if;

  return new;
end;
$$;

create trigger authentication_identities_validate
before insert or update on private.authentication_identities
for each row
execute function private.validate_authentication_identity();

-- ============================================================
-- Resolve technical email by employee number
-- ============================================================

create or replace function private.resolve_login_email(
  login_employee_number text
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select identity.technical_email
  from private.authentication_identities as identity
  inner join app.employees as employee
    on employee.id = identity.employee_id
  where identity.employee_number =
      app.normalize_employee_number(login_employee_number)
    and employee.is_active = true
    and employee.deleted_at is null
  limit 1;
$$;

-- ============================================================
-- Link Supabase Auth user
-- ============================================================

create or replace function private.link_employee_auth_user(
  target_employee_id uuid,
  target_auth_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  auth_email text;
begin
  select lower(trim(auth_user.email))
  into auth_email
  from auth.users as auth_user
  where auth_user.id = target_auth_user_id;

  if auth_email is null then
    raise exception 'Supabase Auth user does not exist or has no email';
  end if;

  update private.authentication_identities
  set auth_user_id = target_auth_user_id
  where employee_id = target_employee_id
    and technical_email = auth_email;

  if not found then
    raise exception
      'Authentication identity does not match employee and Auth user';
  end if;

  update app.employees
  set auth_user_id = target_auth_user_id
  where id = target_employee_id
    and deleted_at is null;

  if not found then
    raise exception 'Employee does not exist or has been deleted';
  end if;
end;
$$;

-- ============================================================
-- Security
-- ============================================================

revoke all on private.authentication_identities
from public, anon, authenticated;

revoke all on function private.normalize_authentication_identity()
from public, anon, authenticated;

revoke all on function private.validate_authentication_identity()
from public, anon, authenticated;

revoke all on function private.resolve_login_email(text)
from public, anon, authenticated;

revoke all on function private.link_employee_auth_user(uuid, uuid)
from public, anon, authenticated;

grant all privileges on private.authentication_identities
to service_role;

grant execute on function private.normalize_authentication_identity()
to service_role;

grant execute on function private.validate_authentication_identity()
to service_role;

grant execute on function private.resolve_login_email(text)
to service_role;

grant execute on function private.link_employee_auth_user(uuid, uuid)
to service_role;

commit;