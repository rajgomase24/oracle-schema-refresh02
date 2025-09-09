# Oracle Schema Refresh Ansible Role

This is an Ansible role for Oracle schema refresh that's optimized for Ansible Automation Tower with all necessary parameters and minimal tasks.

## Role Structure

```
oracle_schema_refresh/
├── defaults
│   └── main.yml
├── tasks
│   ├── main.yml
│   ├── export_schema.yml
│   ├── transfer_dump.yml
│   ├── drop_target_schema.yml
│   └── import_schema.yml
├── templates
│   └── refresh_validation.sql.j2
└── README.md
```

## defaults/main.yml

```yaml
# Source database connection parameters
source_db_host: "{{ inventory_hostname }}"
source_db_port: 1521
source_db_sid: "ORCL"
source_schema: "SOURCE_SCHEM"

# Target database connection parameters
target_db_host: "{{ inventory_hostname }}"
target_db_port: 1521
target_db_sid: "ORCL"
target_schema: "TARGET_SCHEM"

# Database credentials
db_user: "system"
db_password: "required_password"
sys_password: "required_sys_password"

# Data Pump parameters
dump_dir: "DATA_PUMP_DIR"
dump_file_name: "schema_refresh.dmp"
parallel_threads: 4

# Logging parameters
log_dir: "/tmp/refresh_logs"
```

## tasks/main.yml

```yaml
- name: Validate parameters
  fail:
    msg: "{{ item }} is required"
  when: item | default('') == ''
  loop:
    - source_db_host
    - target_db_host
    - source_schema
    - target_schema
    - db_user
    - db_password
    - sys_password

- name: Create log directory
  file:
    path: "{{ log_dir }}"
    state: directory
    mode: '0755'
  delegate_to: localhost

- include_tasks: export_schema.yml
  when: refresh_type != "import_only"

- include_tasks: transfer_dump.yml
  when: 
    - refresh_type != "import_only"
    - source_db_host != target_db_host

- include_tasks: drop_target_schema.yml
  when: refresh_type != "export_only"

- include_tasks: import_schema.yml
  when: refresh_type != "export_only"

- name: Validate refresh operation
  script: "validate_refresh.sql"
  args:
    executable: sqlplus
  environment:
    ORACLE_HOME: "{{ oracle_home }}"
    ORACLE_SID: "{{ target_db_sid }}"
  become_user: "{{ oracle_user }}"
  when: validation_required | bool
```

## tasks/export_schema.yml

```yaml
- name: Export source schema
  command: >
    expdp {{ db_user }}/{{ db_password }}@{{ source_db_host }}:{{ source_db_port }}/{{ source_db_sid }}
    schemas={{ source_schema }}
    directory={{ dump_dir }}
    dumpfile={{ dump_file_name }}
    logfile=export_{{ source_schema }}_{{ ansible_date_time.epoch }}.log
    parallel={{ parallel_threads }}
    compression=ALL
  args:
    executable: "{{ oracle_home }}/bin/expdp"
  environment:
    ORACLE_HOME: "{{ oracle_home }}"
  become_user: "{{ oracle_user }}"
  register: export_result
  failed_when: 
    - export_result.rc != 0
    - "'already exists' not in export_result.stderr"

- name: Check export result
  debug:
    msg: "Schema export completed successfully"
  when: export_result.rc == 0
```

## tasks/transfer_dump.yml

```yaml
- name: Transfer dump file between servers
  synchronize:
    src: "{{ oracle_data_pump_dir }}/{{ dump_file_name }}"
    dest: "{{ oracle_data_pump_dir }}/{{ dump_file_name }}"
    mode: pull
  delegate_to: "{{ target_db_host }}"
  when: source_db_host != target_db_host

- name: Verify transferred file
  stat:
    path: "{{ oracle_data_pump_dir }}/{{ dump_file_name }}"
  register: dump_file_stat
  delegate_to: "{{ target_db_host }}"

- name: Fail if dump file not found
  fail:
    msg: "Dump file not found on target server"
  when: not dump_file_stat.stat.exists
```

## tasks/drop_target_schema.yml

```yaml
- name: Kill active sessions for target schema
  script: |
    #!/bin/bash
    sqlplus -s /nolog <<EOF
    CONNECT sys/{{ sys_password }}@{{ target_db_host }}:{{ target_db_port }}/{{ target_db_sid }} as sysdba
    BEGIN
      FOR sess IN (SELECT sid, serial# FROM v\$session WHERE username = UPPER('{{ target_schema }}'))
      LOOP
        EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || sess.sid || ',' || sess.serial# || ''' IMMEDIATE';
      END LOOP;
    END;
    /
    EOF
  args:
    executable: /bin/bash
  environment:
    ORACLE_HOME: "{{ oracle_home }}"
  become_user: "{{ oracle_user }}"
  ignore_errors: yes

- name: Drop target schema
  script: |
    #!/bin/bash
    sqlplus -s /nolog <<EOF
    CONNECT sys/{{ sys_password }}@{{ target_db_host }}:{{ target_db_port }}/{{ target_db_sid }} as sysdba
    DECLARE
      user_exists NUMBER;
    BEGIN
      SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = UPPER('{{ target_schema }}');
      IF user_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP USER {{ target_schema }} CASCADE';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE;
    END;
    /
    EOF
  args:
    executable: /bin/bash
  environment:
    ORACLE_HOME: "{{ oracle_home }}"
  become_user: "{{ oracle_user }}"
  register: drop_result
  failed_when: 
    - drop_result.rc != 0
    - "'does not exist' not in drop_result.stderr"
```

## tasks/import_schema.yml

```yaml
- name: Import schema to target
  command: >
    impdp {{ db_user }}/{{ db_password }}@{{ target_db_host }}:{{ target_db_port }}/{{ target_db_sid }}
    directory={{ dump_dir }}
    dumpfile={{ dump_file_name }}
    remap_schema={{ source_schema }}:{{ target_schema }}
    transform=segment_attributes:n
    logfile=import_{{ target_schema }}_{{ ansible_date_time.epoch }}.log
    parallel={{ parallel_threads }}
  args:
    executable: "{{ oracle_home }}/bin/impdp"
  environment:
    ORACLE_HOME: "{{ oracle_home }}"
  become_user: "{{ oracle_user }}"
  register: import_result
  failed_when: import_result.rc != 0

- name: Check import result
  debug:
    msg: "Schema import completed successfully"
  when: import_result.rc == 0
```

## templates/refresh_validation.sql.j2

```sql
-- Validation script to verify refresh operation
SET SERVEROUTPUT ON
SET FEEDBACK OFF
DECLARE
  v_object_count NUMBER;
  v_refresh_date VARCHAR2(20);
BEGIN
  -- Check if schema exists
  SELECT COUNT(*) INTO v_object_count 
  FROM all_objects 
  WHERE owner = UPPER('{{ target_schema }}');
  
  IF v_object_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Schema {{ target_schema }} exists with ' || v_object_count || ' objects');
  ELSE
    DBMS_OUTPUT.PUT_LINE('ERROR: Schema {{ target_schema }} has no objects');
    RAISE_APPLICATION_ERROR(-20001, 'Refresh validation failed');
  END IF;
  
  -- Get latest refresh timestamp (assuming there's a table with refresh info)
  BEGIN
    SELECT TO_CHAR(MAX(refresh_date), 'YYYY-MM-DD HH24:MI:SS')
    INTO v_refresh_date
    FROM {{ target_schema }}.refresh_metadata;
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Latest refresh at ' || v_refresh_date);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('INFO: No refresh metadata found');
  END;
END;
/
EXIT;
```

## Role Usage Example

Create a playbook to use this role:

```yaml
- name: Refresh Oracle Schema
  hosts: localhost
  gather_facts: true
  vars:
    refresh_type: "full"  # Options: full, export_only, import_only
    validation_required: true
    oracle_home: "/u01/app/oracle/product/19.3.0/dbhome_1"
    oracle_user: "oracle"
    oracle_data_pump_dir: "/u01/app/oracle/admin/{{ target_db_sid }}/dpdump"
  
  roles:
    - oracle_schema_refresh
```

## Ansible Tower Configuration

1. Create a new Project pointing to your Git repository with this role
2. Create a Job Template with the following parameters:
   - **Extra Variables**:
     ```yaml
     source_db_host: "db-source.example.com"
     target_db_host: "db-target.example.com"
     source_schema: "PROD_SCHEMA"
     target_schema: "TEST_SCHEMA"
     db_password: "{{ vault_db_password }}"
     sys_password: "{{ vault_sys_password }}"
     refresh_type: "full"
     validation_required: true
     ```
   - **Credentials**: Add machine credentials for the database servers
   - **Vault Credentials**: Add vault credentials for database passwords

3. Create Survey for the Job Template with questions for:
   - Source database details
   - Target database details
   - Schema names
   - Refresh type (full, export_only, import_only)
   - Whether to run validation

## Key Features

1. **Minimal and focused tasks**: Only includes essential steps for schema refresh
2. **Flexible parameters**: All configurable aspects are parameterized
3. **Error handling**: Proper failure conditions and error checking
4. **Idempotency**: Can be run multiple times safely
5. **Validation**: Optional post-refresh validation
6. **Cross-server support**: Handles both same-server and cross-server scenarios
7. **Ansible Tower optimized**: Uses surveys, vault credentials, and extra variables

This role provides a clean, maintainable solution for Oracle schema refresh that can be easily configured in Ansible Automation Tower.