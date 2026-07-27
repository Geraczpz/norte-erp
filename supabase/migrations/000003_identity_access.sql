-- ============================================================
-- NORTE-ERP
-- Migration: 000003_identity_access
-- ============================================================

begin;

-- ============================================================
-- Systems
-- ============================================================

create table app.systems (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  base_url text,
  icon_key text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint systems_code_not_blank
    check (length(trim(code)) > 0),

  constraint systems_name_not_blank
    check (length(trim(name)) > 0),

  constraint systems_code_unique
    unique (code)
);

create index systems_active_sort_idx
  on app.systems (is_active, sort_order);

create trigger systems_set_updated_at
before update on app.systems
for each row
execute function app.set_updated_at();

-- ============================================================
-- Employees
-- ============================================================

create table app.employees (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  employee_number text not null,
  first_name text not null,
  middle_name text,
  paternal_last_name text,
  maternal_last_name text not null,
  institutional_email text not null,
  is_active boolean not null default true,
  must_change_password boolean not null default false,
  last_login_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,

  constraint employees_employee_number_not_blank
    check (length(trim(employee_number)) > 0),

  constraint employees_first_name_not_blank
    check (length(trim(first_name)) > 0),

  constraint employees_maternal_last_name_not_blank
    check (length(trim(maternal_last_name)) > 0),

  constraint employees_email_not_blank
    check (length(trim(institutional_email)) > 0),

  constraint employees_email_format
    check (
      institutional_email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    )
);

create unique index employees_employee_number_unique_idx
  on app.employees (
    app.normalize_employee_number(employee_number)
  )
  where deleted_at is null;

create unique index employees_institutional_email_unique_idx
  on app.employees (
    app.normalize_email(institutional_email)
  )
  where deleted_at is null;

create index employees_auth_user_id_idx
  on app.employees (auth_user_id);

create index employees_active_idx
  on app.employees (is_active)
  where deleted_at is null;

create trigger employees_set_updated_at
before update on app.employees
for each row
execute function app.set_updated_at();

-- ============================================================
-- Roles
-- ============================================================

create table app.roles (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references app.systems(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  is_system_role boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint roles_code_not_blank
    check (length(trim(code)) > 0),

  constraint roles_name_not_blank
    check (length(trim(name)) > 0),

  constraint roles_system_code_unique
    unique (system_id, code)
);

create index roles_system_active_idx
  on app.roles (system_id, is_active);

create trigger roles_set_updated_at
before update on app.roles
for each row
execute function app.set_updated_at();

-- ============================================================
-- Permissions
-- ============================================================

create table app.permissions (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references app.systems(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  resource text not null,
  action text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint permissions_code_not_blank
    check (length(trim(code)) > 0),

  constraint permissions_name_not_blank
    check (length(trim(name)) > 0),

  constraint permissions_resource_not_blank
    check (length(trim(resource)) > 0),

  constraint permissions_action_not_blank
    check (length(trim(action)) > 0),

  constraint permissions_system_code_unique
    unique (system_id, code)
);

create index permissions_system_active_idx
  on app.permissions (system_id, is_active);

create index permissions_resource_action_idx
  on app.permissions (resource, action);

create trigger permissions_set_updated_at
before update on app.permissions
for each row
execute function app.set_updated_at();

-- ============================================================
-- Role permissions
-- ============================================================

create table app.role_permissions (
  role_id uuid not null references app.roles(id) on delete cascade,
  permission_id uuid not null references app.permissions(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),

  primary key (role_id, permission_id)
);

create index role_permissions_permission_idx
  on app.role_permissions (permission_id);

-- ============================================================
-- Employee system access
-- ============================================================

create table app.employee_system_access (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references app.employees(id) on delete cascade,
  system_id uuid not null references app.systems(id) on delete cascade,
  is_active boolean not null default true,
  granted_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint employee_system_access_unique
    unique (employee_id, system_id),

  constraint employee_system_access_revocation_consistency
    check (
      (is_active = true and revoked_at is null)
      or
      (is_active = false)
    )
);

create index employee_system_access_employee_idx
  on app.employee_system_access (employee_id, is_active);

create index employee_system_access_system_idx
  on app.employee_system_access (system_id, is_active);

create trigger employee_system_access_set_updated_at
before update on app.employee_system_access
for each row
execute function app.set_updated_at();

-- ============================================================
-- Employee roles
-- ============================================================

create table app.employee_roles (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references app.employees(id) on delete cascade,
  role_id uuid not null references app.roles(id) on delete cascade,
  assigned_at timestamptz not null default timezone('utc', now()),
  assigned_by uuid references app.employees(id) on delete set null,
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint employee_roles_unique
    unique (employee_id, role_id),

  constraint employee_roles_expiration_valid
    check (
      expires_at is null
      or expires_at > assigned_at
    )
);

create index employee_roles_employee_active_idx
  on app.employee_roles (employee_id, is_active);

create index employee_roles_role_active_idx
  on app.employee_roles (role_id, is_active);

create index employee_roles_expiration_idx
  on app.employee_roles (expires_at)
  where expires_at is not null;

create trigger employee_roles_set_updated_at
before update on app.employee_roles
for each row
execute function app.set_updated_at();

commit;