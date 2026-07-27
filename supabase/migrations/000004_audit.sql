-- ============================================================
-- NORTE-ERP
-- Migration: 000004_audit
-- ============================================================

begin;

-- ============================================================
-- Audit logs
-- ============================================================

create table audit.logs (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamptz not null default timezone('utc', now()),
  actor_auth_user_id uuid references auth.users(id) on delete set null,
  actor_employee_id uuid references app.employees(id) on delete set null,
  system_id uuid references app.systems(id) on delete set null,
  action text not null,
  entity_schema text not null,
  entity_table text not null,
  entity_id text,
  request_id uuid,
  ip_address inet,
  user_agent text,
  old_data jsonb,
  new_data jsonb,
  metadata jsonb not null default '{}'::jsonb,

  constraint audit_logs_action_not_blank
    check (length(trim(action)) > 0),

  constraint audit_logs_entity_schema_not_blank
    check (length(trim(entity_schema)) > 0),

  constraint audit_logs_entity_table_not_blank
    check (length(trim(entity_table)) > 0)
);

create index audit_logs_occurred_at_idx
  on audit.logs (occurred_at desc);

create index audit_logs_actor_employee_idx
  on audit.logs (actor_employee_id, occurred_at desc);

create index audit_logs_actor_auth_user_idx
  on audit.logs (actor_auth_user_id, occurred_at desc);

create index audit_logs_system_idx
  on audit.logs (system_id, occurred_at desc);

create index audit_logs_entity_idx
  on audit.logs (
    entity_schema,
    entity_table,
    entity_id,
    occurred_at desc
  );

create index audit_logs_action_idx
  on audit.logs (action, occurred_at desc);

create trigger audit_logs_prevent_update
before update on audit.logs
for each row
execute function audit.prevent_mutation();

create trigger audit_logs_prevent_delete
before delete on audit.logs
for each row
execute function audit.prevent_mutation();

-- ============================================================
-- Generic audit trigger function
-- ============================================================

create or replace function audit.capture_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  authenticated_user_id uuid;
  authenticated_employee_id uuid;
  affected_entity_id text;
  old_record jsonb;
  new_record jsonb;
begin
  authenticated_user_id := auth.uid();

  if authenticated_user_id is not null then
    select employee.id
    into authenticated_employee_id
    from app.employees as employee
    where employee.auth_user_id = authenticated_user_id
      and employee.deleted_at is null
    limit 1;
  end if;

  if tg_op = 'INSERT' then
    old_record := null;
    new_record := to_jsonb(new);
    affected_entity_id := new_record ->> 'id';
  elsif tg_op = 'UPDATE' then
    old_record := to_jsonb(old);
    new_record := to_jsonb(new);
    affected_entity_id := coalesce(
      new_record ->> 'id',
      old_record ->> 'id'
    );
  elsif tg_op = 'DELETE' then
    old_record := to_jsonb(old);
    new_record := null;
    affected_entity_id := old_record ->> 'id';
  else
    raise exception 'Unsupported audit operation: %', tg_op;
  end if;

  insert into audit.logs (
    actor_auth_user_id,
    actor_employee_id,
    action,
    entity_schema,
    entity_table,
    entity_id,
    old_data,
    new_data
  )
  values (
    authenticated_user_id,
    authenticated_employee_id,
    tg_op,
    tg_table_schema,
    tg_table_name,
    affected_entity_id,
    old_record,
    new_record
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

-- ============================================================
-- Audit triggers
-- ============================================================

create trigger systems_audit
after insert or update or delete on app.systems
for each row
execute function audit.capture_change();

create trigger employees_audit
after insert or update or delete on app.employees
for each row
execute function audit.capture_change();

create trigger roles_audit
after insert or update or delete on app.roles
for each row
execute function audit.capture_change();

create trigger permissions_audit
after insert or update or delete on app.permissions
for each row
execute function audit.capture_change();

create trigger role_permissions_audit
after insert or update or delete on app.role_permissions
for each row
execute function audit.capture_change();

create trigger employee_system_access_audit
after insert or update or delete on app.employee_system_access
for each row
execute function audit.capture_change();

create trigger employee_roles_audit
after insert or update or delete on app.employee_roles
for each row
execute function audit.capture_change();

-- ============================================================
-- Permissions
-- ============================================================

revoke all on audit.logs from public;
revoke all on audit.logs from anon;
revoke all on audit.logs from authenticated;

grant select, insert on audit.logs to service_role;

commit;