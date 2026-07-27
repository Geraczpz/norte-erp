-- ============================================================
-- NORTE-ERP
-- Migration: 000008_access_views
-- ============================================================

begin;

-- ============================================================
-- Employee effective permissions
-- ============================================================

create or replace view app.employee_effective_permissions
with (security_invoker = true)
as
select distinct
  employee.id as employee_id,
  employee.employee_number,
  system.id as system_id,
  system.code as system_code,
  system.name as system_name,
  role.id as role_id,
  role.code as role_code,
  role.name as role_name,
  permission.id as permission_id,
  permission.code as permission_code,
  permission.name as permission_name,
  permission.resource,
  permission.action
from app.employees as employee
inner join app.employee_system_access as system_access
  on system_access.employee_id = employee.id
inner join app.systems as system
  on system.id = system_access.system_id
inner join app.employee_roles as employee_role
  on employee_role.employee_id = employee.id
inner join app.roles as role
  on role.id = employee_role.role_id
  and role.system_id = system.id
inner join app.role_permissions as role_permission
  on role_permission.role_id = role.id
inner join app.permissions as permission
  on permission.id = role_permission.permission_id
  and permission.system_id = system.id
where employee.is_active = true
  and employee.deleted_at is null
  and system_access.is_active = true
  and system_access.revoked_at is null
  and system.is_active = true
  and employee_role.is_active = true
  and (
    employee_role.expires_at is null
    or employee_role.expires_at > timezone('utc', now())
  )
  and role.is_active = true
  and permission.is_active = true;

-- ============================================================
-- Employee accessible systems
-- ============================================================

create or replace view app.employee_accessible_systems
with (security_invoker = true)
as
select
  employee.id as employee_id,
  employee.employee_number,
  system.id as system_id,
  system.code as system_code,
  system.name as system_name,
  system.description,
  system.base_url,
  system.icon_key,
  system.sort_order,
  system_access.granted_at
from app.employees as employee
inner join app.employee_system_access as system_access
  on system_access.employee_id = employee.id
inner join app.systems as system
  on system.id = system_access.system_id
where employee.is_active = true
  and employee.deleted_at is null
  and system_access.is_active = true
  and system_access.revoked_at is null
  and system.is_active = true;

-- ============================================================
-- Employee role assignments
-- ============================================================

create or replace view app.employee_role_assignments
with (security_invoker = true)
as
select
  employee_role.id as assignment_id,
  employee.id as employee_id,
  employee.employee_number,
  system.id as system_id,
  system.code as system_code,
  role.id as role_id,
  role.code as role_code,
  role.name as role_name,
  employee_role.assigned_at,
  employee_role.expires_at,
  employee_role.is_active
from app.employee_roles as employee_role
inner join app.employees as employee
  on employee.id = employee_role.employee_id
inner join app.roles as role
  on role.id = employee_role.role_id
inner join app.systems as system
  on system.id = role.system_id
where employee.deleted_at is null;

-- ============================================================
-- Security
-- ============================================================

revoke all on app.employee_effective_permissions
from public, anon, authenticated;

revoke all on app.employee_accessible_systems
from public, anon, authenticated;

revoke all on app.employee_role_assignments
from public, anon, authenticated;

grant select on app.employee_effective_permissions
to service_role;

grant select on app.employee_accessible_systems
to service_role;

grant select on app.employee_role_assignments
to service_role;

commit;