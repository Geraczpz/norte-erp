-- ============================================================
-- NORTE-ERP
-- Database structure verification
-- ============================================================

do $$
declare
  missing_objects text[];
begin
  select array_agg(required_object.object_name)
  into missing_objects
  from (
    values
      ('schema:app', to_regnamespace('app') is not null),
      ('schema:audit', to_regnamespace('audit') is not null),
      ('schema:private', to_regnamespace('private') is not null),

      ('table:app.systems', to_regclass('app.systems') is not null),
      ('table:app.employees', to_regclass('app.employees') is not null),
      ('table:app.roles', to_regclass('app.roles') is not null),
      ('table:app.permissions', to_regclass('app.permissions') is not null),
      ('table:app.role_permissions', to_regclass('app.role_permissions') is not null),
      (
        'table:app.employee_system_access',
        to_regclass('app.employee_system_access') is not null
      ),
      ('table:app.employee_roles', to_regclass('app.employee_roles') is not null),
      ('table:app.system_settings', to_regclass('app.system_settings') is not null),

      ('table:audit.logs', to_regclass('audit.logs') is not null),

      (
        'table:private.authentication_identities',
        to_regclass('private.authentication_identities') is not null
      ),

      (
        'view:app.employee_effective_permissions',
        to_regclass('app.employee_effective_permissions') is not null
      ),
      (
        'view:app.employee_accessible_systems',
        to_regclass('app.employee_accessible_systems') is not null
      ),
      (
        'view:app.employee_role_assignments',
        to_regclass('app.employee_role_assignments') is not null
      )
  ) as required_object(object_name, object_exists)
  where required_object.object_exists = false;

  if missing_objects is not null then
    raise exception
      'Missing required database objects: %',
      array_to_string(missing_objects, ', ');
  end if;
end;
$$;

-- ============================================================
-- Verify NORTE-ERP seed
-- ============================================================

do $$
declare
  system_count integer;
  role_count integer;
  permission_count integer;
  setting_count integer;
begin
  select count(*)
  into system_count
  from app.systems
  where code = 'NORTE_ERP';

  if system_count <> 1 then
    raise exception
      'Expected 1 NORTE_ERP system, found %',
      system_count;
  end if;

  select count(*)
  into role_count
  from app.roles as role
  inner join app.systems as system
    on system.id = role.system_id
  where system.code = 'NORTE_ERP';

  if role_count <> 5 then
    raise exception
      'Expected 5 NORTE_ERP roles, found %',
      role_count;
  end if;

  select count(*)
  into permission_count
  from app.permissions as permission
  inner join app.systems as system
    on system.id = permission.system_id
  where system.code = 'NORTE_ERP';

  if permission_count <> 23 then
    raise exception
      'Expected 23 NORTE_ERP permissions, found %',
      permission_count;
  end if;

  select count(*)
  into setting_count
  from app.system_settings as setting
  inner join app.systems as system
    on system.id = setting.system_id
  where system.code = 'NORTE_ERP';

  if setting_count <> 6 then
    raise exception
      'Expected 6 NORTE_ERP settings, found %',
      setting_count;
  end if;
end;
$$;

-- ============================================================
-- Verify Row Level Security
-- ============================================================

do $$
declare
  unsecured_tables text[];
begin
  select array_agg(
    table_status.schemaname || '.' || table_status.tablename
  )
  into unsecured_tables
  from pg_tables as table_status
  where table_status.schemaname in ('app', 'audit')
    and table_status.tablename in (
      'systems',
      'employees',
      'roles',
      'permissions',
      'role_permissions',
      'employee_system_access',
      'employee_roles',
      'system_settings',
      'logs'
    )
    and table_status.rowsecurity = false;

  if unsecured_tables is not null then
    raise exception
      'RLS is disabled on: %',
      array_to_string(unsecured_tables, ', ');
  end if;
end;
$$;

-- ============================================================
-- Verification result
-- ============================================================

select
  'NORTE-ERP database structure verified successfully' as result,
  timezone('utc', now()) as verified_at;