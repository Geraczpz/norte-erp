-- ============================================================
-- NORTE-ERP
-- Migration: 000009_system_settings
-- ============================================================

begin;

-- ============================================================
-- System settings
-- ============================================================

create table app.system_settings (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references app.systems(id) on delete cascade,
  key text not null,
  value jsonb not null default 'null'::jsonb,
  description text,
  is_public boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by_employee_id uuid references app.employees(id) on delete set null,
  updated_by_employee_id uuid references app.employees(id) on delete set null,

  constraint system_settings_key_not_blank
    check (length(trim(key)) > 0),

  constraint system_settings_system_key_unique
    unique (system_id, key)
);

create index system_settings_system_id_idx
  on app.system_settings (system_id);

create index system_settings_public_idx
  on app.system_settings (system_id, is_public)
  where is_public = true;

-- ============================================================
-- Normalize settings
-- ============================================================

create or replace function app.normalize_system_setting()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.key := lower(trim(new.key));
  new.description := nullif(trim(new.description), '');

  return new;
end;
$$;

create trigger system_settings_normalize
before insert or update on app.system_settings
for each row
execute function app.normalize_system_setting();

-- ============================================================
-- Updated timestamp
-- ============================================================

create trigger system_settings_set_updated_at
before update on app.system_settings
for each row
execute function app.set_updated_at();

-- ============================================================
-- Audit
-- ============================================================

create trigger system_settings_audit
after insert or update or delete on app.system_settings
for each row
execute function audit.capture_change();

-- ============================================================
-- Row Level Security
-- ============================================================

alter table app.system_settings enable row level security;

-- ============================================================
-- Security
-- ============================================================

revoke all on app.system_settings
from public, anon, authenticated;

revoke all on function app.normalize_system_setting()
from public, anon, authenticated;

grant all privileges on app.system_settings
to service_role;

grant execute on function app.normalize_system_setting()
to service_role;

-- ============================================================
-- Seed NORTE-ERP settings
-- ============================================================

insert into app.system_settings (
  system_id,
  key,
  value,
  description,
  is_public
)
select
  system.id,
  setting.key,
  setting.value,
  setting.description,
  setting.is_public
from app.systems as system
cross join (
  values
    (
      'application.name',
      '"NORTE-ERP"'::jsonb,
      'Nombre visible de la aplicación.',
      true
    ),
    (
      'application.description',
      '"Portal central de autenticación, usuarios, roles y permisos."'::jsonb,
      'Descripción general de la aplicación.',
      true
    ),
    (
      'authentication.employee_number_enabled',
      'true'::jsonb,
      'Permite iniciar sesión mediante matrícula.',
      false
    ),
    (
      'authentication.require_password_change_on_first_login',
      'true'::jsonb,
      'Solicita cambiar la contraseña durante el primer inicio de sesión.',
      false
    ),
    (
      'security.audit_enabled',
      'true'::jsonb,
      'Activa el registro de auditoría.',
      false
    ),
    (
      'security.session_timeout_minutes',
      '480'::jsonb,
      'Duración máxima de una sesión en minutos.',
      false
    )
) as setting (
  key,
  value,
  description,
  is_public
)
where system.code = 'NORTE_ERP'
on conflict (system_id, key)
do update set
  value = excluded.value,
  description = excluded.description,
  is_public = excluded.is_public,
  updated_at = timezone('utc', now());

commit;