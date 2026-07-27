-- ============================================================
-- NORTE-ERP
-- Migration: 000007_norte_erp_seed
-- ============================================================

begin;

-- ============================================================
-- Main system
-- ============================================================

insert into app.systems (
  code,
  name,
  description,
  base_url,
  icon_key,
  is_active,
  sort_order
)
values (
  'NORTE_ERP',
  'NORTE-ERP',
  'Sistema central de autenticación, usuarios, roles y permisos.',
  null,
  'norte-erp',
  true,
  1
)
on conflict (code)
do update set
  name = excluded.name,
  description = excluded.description,
  icon_key = excluded.icon_key,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

-- ============================================================
-- Permissions
-- ============================================================

insert into app.permissions (
  system_id,
  code,
  name,
  description,
  resource,
  action
)
select
  system.id,
  permission.code,
  permission.name,
  permission.description,
  permission.resource,
  permission.action
from app.systems as system
cross join (
  values
    (
      'dashboard.view',
      'Ver dashboard',
      'Permite acceder al dashboard principal.',
      'dashboard',
      'view'
    ),
    (
      'users.view',
      'Ver usuarios',
      'Permite consultar empleados y usuarios.',
      'users',
      'view'
    ),
    (
      'users.create',
      'Crear usuarios',
      'Permite crear empleados y usuarios.',
      'users',
      'create'
    ),
    (
      'users.update',
      'Actualizar usuarios',
      'Permite modificar empleados y usuarios.',
      'users',
      'update'
    ),
    (
      'users.deactivate',
      'Desactivar usuarios',
      'Permite desactivar empleados y usuarios.',
      'users',
      'deactivate'
    ),
    (
      'users.assign_systems',
      'Asignar sistemas',
      'Permite asignar acceso a sistemas.',
      'users',
      'assign_systems'
    ),
    (
      'users.assign_roles',
      'Asignar roles',
      'Permite asignar roles a empleados.',
      'users',
      'assign_roles'
    ),
    (
      'systems.view',
      'Ver sistemas',
      'Permite consultar los sistemas registrados.',
      'systems',
      'view'
    ),
    (
      'systems.create',
      'Crear sistemas',
      'Permite registrar sistemas.',
      'systems',
      'create'
    ),
    (
      'systems.update',
      'Actualizar sistemas',
      'Permite modificar sistemas.',
      'systems',
      'update'
    ),
    (
      'systems.deactivate',
      'Desactivar sistemas',
      'Permite desactivar sistemas.',
      'systems',
      'deactivate'
    ),
    (
      'roles.view',
      'Ver roles',
      'Permite consultar roles.',
      'roles',
      'view'
    ),
    (
      'roles.create',
      'Crear roles',
      'Permite crear roles.',
      'roles',
      'create'
    ),
    (
      'roles.update',
      'Actualizar roles',
      'Permite modificar roles.',
      'roles',
      'update'
    ),
    (
      'roles.deactivate',
      'Desactivar roles',
      'Permite desactivar roles.',
      'roles',
      'deactivate'
    ),
    (
      'roles.assign_permissions',
      'Asignar permisos a roles',
      'Permite administrar los permisos de los roles.',
      'roles',
      'assign_permissions'
    ),
    (
      'permissions.view',
      'Ver permisos',
      'Permite consultar permisos.',
      'permissions',
      'view'
    ),
    (
      'permissions.create',
      'Crear permisos',
      'Permite registrar permisos.',
      'permissions',
      'create'
    ),
    (
      'permissions.update',
      'Actualizar permisos',
      'Permite modificar permisos.',
      'permissions',
      'update'
    ),
    (
      'permissions.deactivate',
      'Desactivar permisos',
      'Permite desactivar permisos.',
      'permissions',
      'deactivate'
    ),
    (
      'audit.view',
      'Ver auditoría',
      'Permite consultar el historial de auditoría.',
      'audit',
      'view'
    ),
    (
      'settings.view',
      'Ver configuración',
      'Permite consultar la configuración general.',
      'settings',
      'view'
    ),
    (
      'settings.update',
      'Actualizar configuración',
      'Permite modificar la configuración general.',
      'settings',
      'update'
    )
) as permission (
  code,
  name,
  description,
  resource,
  action
)
where system.code = 'NORTE_ERP'
on conflict (system_id, code)
do update set
  name = excluded.name,
  description = excluded.description,
  resource = excluded.resource,
  action = excluded.action,
  is_active = true;

-- ============================================================
-- Roles
-- ============================================================

insert into app.roles (
  system_id,
  code,
  name,
  description,
  is_system_role,
  is_active
)
select
  system.id,
  role.code,
  role.name,
  role.description,
  role.is_system_role,
  true
from app.systems as system
cross join (
  values
    (
      'super_admin',
      'Superadministrador',
      'Acceso total a NORTE-ERP.',
      true
    ),
    (
      'user_admin',
      'Administrador de usuarios',
      'Administra usuarios, accesos y asignaciones.',
      true
    ),
    (
      'security_admin',
      'Administrador de seguridad',
      'Administra roles y permisos.',
      true
    ),
    (
      'auditor',
      'Auditor',
      'Consulta información y registros de auditoría.',
      true
    ),
    (
      'employee',
      'Empleado',
      'Acceso básico al portal y sistemas asignados.',
      true
    )
) as role (
  code,
  name,
  description,
  is_system_role
)
where system.code = 'NORTE_ERP'
on conflict (system_id, code)
do update set
  name = excluded.name,
  description = excluded.description,
  is_system_role = excluded.is_system_role,
  is_active = true;

-- ============================================================
-- Superadministrator permissions
-- ============================================================

insert into app.role_permissions (
  role_id,
  permission_id
)
select
  role.id,
  permission.id
from app.roles as role
inner join app.systems as system
  on system.id = role.system_id
inner join app.permissions as permission
  on permission.system_id = system.id
where system.code = 'NORTE_ERP'
  and role.code = 'super_admin'
on conflict (role_id, permission_id)
do nothing;

-- ============================================================
-- User administrator permissions
-- ============================================================

insert into app.role_permissions (
  role_id,
  permission_id
)
select
  role.id,
  permission.id
from app.roles as role
inner join app.systems as system
  on system.id = role.system_id
inner join app.permissions as permission
  on permission.system_id = system.id
where system.code = 'NORTE_ERP'
  and role.code = 'user_admin'
  and permission.code in (
    'dashboard.view',
    'users.view',
    'users.create',
    'users.update',
    'users.deactivate',
    'users.assign_systems',
    'users.assign_roles',
    'systems.view',
    'roles.view'
  )
on conflict (role_id, permission_id)
do nothing;

-- ============================================================
-- Security administrator permissions
-- ============================================================

insert into app.role_permissions (
  role_id,
  permission_id
)
select
  role.id,
  permission.id
from app.roles as role
inner join app.systems as system
  on system.id = role.system_id
inner join app.permissions as permission
  on permission.system_id = system.id
where system.code = 'NORTE_ERP'
  and role.code = 'security_admin'
  and permission.code in (
    'dashboard.view',
    'systems.view',
    'roles.view',
    'roles.create',
    'roles.update',
    'roles.deactivate',
    'roles.assign_permissions',
    'permissions.view',
    'permissions.create',
    'permissions.update',
    'permissions.deactivate'
  )
on conflict (role_id, permission_id)
do nothing;

-- ============================================================
-- Auditor permissions
-- ============================================================

insert into app.role_permissions (
  role_id,
  permission_id
)
select
  role.id,
  permission.id
from app.roles as role
inner join app.systems as system
  on system.id = role.system_id
inner join app.permissions as permission
  on permission.system_id = system.id
where system.code = 'NORTE_ERP'
  and role.code = 'auditor'
  and permission.code in (
    'dashboard.view',
    'users.view',
    'systems.view',
    'roles.view',
    'permissions.view',
    'audit.view',
    'settings.view'
  )
on conflict (role_id, permission_id)
do nothing;

-- ============================================================
-- Employee permissions
-- ============================================================

insert into app.role_permissions (
  role_id,
  permission_id
)
select
  role.id,
  permission.id
from app.roles as role
inner join app.systems as system
  on system.id = role.system_id
inner join app.permissions as permission
  on permission.system_id = system.id
where system.code = 'NORTE_ERP'
  and role.code = 'employee'
  and permission.code = 'dashboard.view'
on conflict (role_id, permission_id)
do nothing;

commit;