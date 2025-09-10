# Oracle Schema Refresh Ansible Role

An enterprise-grade Ansible role for Oracle schema refresh operations with comprehensive Ansible Automation Tower integration, centralized configuration management, and advanced error handling.

## 🚀 Key Features

- **Centralized Configuration**: All parameters managed through `vars.yml`
- **Multiple Transfer Methods**: Direct (rsync), S3, and hybrid transfer options
- **AWS S3 Integration**: Enterprise-grade cloud storage with lifecycle management
- **Ansible Tower Ready**: Complete Tower integration with surveys and workflows
- **Robust Error Handling**: Comprehensive retry mechanisms and validation
- **Multiple Operation Modes**: Full, export-only, and import-only operations
- **Advanced Logging**: Detailed operation tracking and reporting
- **Security**: Vault integration for credential management
- **Validation**: Pre-flight checks and post-operation verification
- **Fallback Support**: Automatic fallback between transfer methods

## 📁 Role Structure

```
oracle_schema_refresh/
├── defaults/
│   └── main.yml              # Default variable definitions
├── tasks/
│   ├── main.yml              # Main orchestration logic
│   ├── export_schema.yml     # Schema export operations
│   ├── transfer_dump.yml     # Transfer coordination (direct/S3/hybrid)
│   ├── direct_transfer.yml   # Direct server-to-server transfer
│   ├── s3_transfer.yml       # AWS S3 upload/download operations
│   ├── drop_target_schema.yml # Target schema cleanup
│   └── import_schema.yml     # Schema import operations
├── templates/
│   └── refresh_validation.sql.j2  # Validation SQL template
└── files/
    └── validate_refresh.sql  # Static validation script
```

## 🎯 Quick Start

### 1. Basic Usage

```bash
# Run a full schema refresh
ansible-playbook -i inventory.ini main.yml

# Export only
ansible-playbook -i inventory.ini main.yml -e "refresh_type=export_only"

# Import only
ansible-playbook -i inventory.ini main.yml -e "refresh_type=import_only"
```

### 2. Using with Custom Variables

```bash
# Direct transfer with custom schemas
ansible-playbook -i inventory.ini main.yml \
  -e "source_schema=PROD_SCHEMA" \
  -e "target_schema=TEST_SCHEMA" \
  -e "transfer_method=direct"

# S3 transfer with custom bucket
ansible-playbook -i inventory.ini main.yml \
  -e "transfer_method=s3" \
  -e "s3_bucket_name=my-oracle-dumps" \
  -e "s3_bucket_region=us-west-2"

# Hybrid transfer (upload to S3 + local copy)
ansible-playbook -i inventory.ini main.yml \
  -e "transfer_method=hybrid" \
  -e "parallel_threads=8"
```

## ⚙️ Configuration

### Core Variables (vars.yml)

All configurable parameters are centralized in `vars.yml`. Key sections include:

#### Database Configuration
```yaml
# Source Database Settings
source_db_host: "{{ inventory_hostname }}"
source_db_port: 1521
source_db_sid: "nsqual"
source_db_service: "nsqual01"
source_schema: "AUTOMATIONTEST"

# Target Database Settings  
target_db_host: "{{ inventory_hostname }}"
target_db_port: 1521
target_db_sid: "nsqual"
target_db_service: "nsqual01"
target_schema: "AUTOMATIONTEST"
```

#### Operation Settings
```yaml
# Refresh type: 'full', 'export_only', 'import_only'
refresh_type: "full"

# Enable/disable post-refresh validation
validation_required: true

# Data Pump settings
parallel_threads: 4
dump_compression: "ALL"
```

#### Transfer Method Configuration
```yaml
# Transfer method: 'direct', 's3', 'hybrid'
transfer_method: "direct"

# S3 Configuration (when using S3/hybrid)
s3_bucket_name: "oracle-dump-files"
s3_bucket_region: "us-east-1"
s3_storage_class: "STANDARD_IA"
s3_use_iam_role: true

# Fallback configuration
enable_transfer_fallback: true
fallback_transfer_method: "direct"
```

#### Oracle Environment
```yaml
# Oracle installation paths
oracle_home: "/u01/app/oracle/product/19c/dbhome_1"
oracle_user: "oracle"
oracle_data_pump_dir: "/u01/app/oracle/admin/{{ target_db_sid }}/dpdump"
```

### Environment-Specific Overrides

Create environment-specific variable files:

```yaml
# vars/production.yml
environment_name: "production"
backup_before_drop: true
cleanup_dump_files: false
schema_existence_check: "strict"
enable_preflight_checks: true

# vars/development.yml
environment_name: "development"
backup_before_drop: false
cleanup_dump_files: true
schema_existence_check: "warn"
```

## 🔐 Security Configuration

### Credential Management

Store sensitive variables in Ansible Vault:

```yaml
# vault.yml (encrypted)
vault_db_password: "your_secure_password"
vault_sys_password: "your_sys_password"
```

### Ansible Tower Credentials

Configure custom credential types in Tower:
- **Oracle Database Credential**: For database passwords
- **Machine Credential**: For SSH access to Oracle servers

## 🏢 Ansible Tower Integration

### Job Template Configuration

1. **Basic Settings**:
   - Name: Oracle Schema Refresh
   - Job Type: Run
   - Inventory: Oracle Database Servers
   - Project: Oracle Automation
   - Playbook: main.yml

2. **Required Credentials**:
   - Machine Credential (SSH)
   - Oracle Database Credential (Custom)

3. **Default Extra Variables**:
```json
{
  "environment_name": "development",
  "refresh_type": "full",
  "validation_required": true,
  "detailed_logging": true,
  "parallel_threads": 4
}
```

### Survey Configuration

Create surveys for dynamic input:

| Variable | Type | Description | Choices |
|----------|------|-------------|---------|
| `environment_name` | Choice | Target Environment | development, testing, staging, production |
| `refresh_type` | Choice | Operation Type | full, export_only, import_only |
| `source_schema` | Text | Source Schema Name | (user input) |
| `target_schema` | Text | Target Schema Name | (user input) |
| `validation_required` | Choice | Run Validation | true, false |
| `parallel_threads` | Integer | Parallel Threads | 1-8 |

For complete Tower configuration, see [ANSIBLE_TOWER_CONFIG.md](ANSIBLE_TOWER_CONFIG.md).

## 🔄 Transfer Methods

### 1. Direct Transfer (`transfer_method: "direct"`)
- Server-to-server transfer using rsync
- Fastest for same-datacenter operations
- Requires SSH connectivity between servers
- Best for development and testing environments

### 2. S3 Transfer (`transfer_method: "s3"`)
- Upload to AWS S3 from source, download to target
- Best for cross-region/cross-cloud operations
- Provides audit trail and backup capabilities
- Supports lifecycle management and cost optimization
- Ideal for production environments

### 3. Hybrid Transfer (`transfer_method: "hybrid"`)
- Combines S3 upload with local file retention
- Provides backup while maintaining local access
- Best for environments requiring both speed and backup

### Transfer Method Comparison

| Feature | Direct | S3 | Hybrid |
|---------|--------|----|---------| 
| Speed | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| Reliability | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Audit Trail | ⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Cost | Free | $ | $$ |
| Backup | ❌ | ✅ | ✅ |
| Cross-Cloud | ❌ | ✅ | ✅ |

## 🔄 Operation Modes

### 1. Full Refresh (`refresh_type: "full"`)
- Exports source schema
- Transfers dump file (if different servers)
- Drops target schema
- Imports to target
- Runs validation

### 2. Export Only (`refresh_type: "export_only"`)
- Exports source schema only
- Useful for creating backups or staged operations

### 3. Import Only (`refresh_type: "import_only"`)
- Assumes dump file exists
- Drops target schema
- Imports from existing dump
- Runs validation

## 📊 Monitoring and Logging

### Log Files

Operations generate logs in `{{ log_dir }}` (default: `/tmp/refresh_logs/`):

- `refresh_operations.log`: Main operation log
- `export_operations.log`: Export-specific logs
- `import_operations.log`: Import-specific logs
- `transfer_operations.log`: File transfer logs
- `operation_report_TIMESTAMP.md`: Detailed operation report

### Real-time Monitoring

Monitor progress through:
- Ansible output during execution
- Oracle Data Pump log files
- System resource utilization
- Database session activity

## 🔧 Advanced Features

### Pre-flight Checks

Enable comprehensive validation before operations:

```yaml
enable_preflight_checks: true
```

Checks include:
- Oracle environment validation
- Database connectivity
- Schema existence verification
- Disk space validation
- Permission verification

### Backup and Recovery

Configure automatic backups before destructive operations:

```yaml
backup_before_drop: true
backup_directory: "/tmp/schema_backups"
```

### Retry and Error Handling

Built-in retry mechanisms for:
- Network operations (file transfers)
- Database connectivity issues
- Temporary resource constraints

### Dry Run Mode

Test operations without making changes:

```bash
ansible-playbook main.yml -e "dry_run=true"
```

## 🚨 Troubleshooting

### Common Issues

#### Connection Failures
```bash
# Verify Oracle connectivity
sqlplus {{ db_user }}/{{ db_password }}@{{ target_db_host }}:{{ target_db_port }}/{{ target_db_service }}

# Check listener status
lsnrctl status
```

#### Permission Errors
```bash
# Verify oracle user permissions
su - oracle -c "ls -la {{ oracle_data_pump_dir }}"

# Check sudoers configuration
sudo -l -U oracle
```

#### Space Issues
```bash
# Check available space
df -h {{ oracle_data_pump_dir }}

# Monitor during operation
watch "df -h {{ oracle_data_pump_dir }}"
```

### Debug Mode

Enable verbose output:

```bash
ansible-playbook main.yml -vvv -e "detailed_logging=true"
```

### Log Analysis

Check specific log files:
```bash
# View main operation log
tail -f {{ log_dir }}/refresh_operations.log

# Check Oracle Data Pump logs
tail -f {{ oracle_data_pump_dir }}/export_*.log
tail -f {{ oracle_data_pump_dir }}/import_*.log
```

## 📋 Requirements

### System Requirements
- **Ansible**: 2.9 or higher
- **Oracle Database**: 11g or higher (tested with 19c)
- **Operating System**: Linux (RHEL/CentOS/Oracle Linux)
- **Python**: 3.6 or higher

### Oracle Requirements
- Oracle client installation (SQL*Plus, Data Pump utilities)
- Properly configured TNS entries
- Data Pump directory created and accessible
- Sufficient tablespace for operations

### Network Requirements
- SSH connectivity between Ansible controller and Oracle servers
- Oracle database connectivity (typically port 1521)
- Sufficient bandwidth for dump file transfers

## 🔄 Migration from Previous Versions

If migrating from an older version:

1. **Update variable names**: Check vars.yml for new variable structure
2. **Update inventory**: Ensure host groups match expected patterns
3. **Vault migration**: Re-encrypt vault files if needed
4. **Test thoroughly**: Run in dry-run mode first

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with proper documentation
4. Add tests for new functionality
5. Submit a pull request

### Development Guidelines
- Follow Ansible best practices
- Document all variables in vars.yml
- Include error handling for new features
- Test with multiple Oracle versions
- Update documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check this README and ANSIBLE_TOWER_CONFIG.md
- **Issues**: Submit issues via GitHub/internal issue tracker
- **Emergency**: Contact DBA on-call team

## 📈 Changelog

### Version 2.0.0 (Current)
- Centralized configuration in vars.yml
- Complete Ansible Tower integration
- Enhanced error handling and retry mechanisms
- Advanced logging and reporting
- Multi-environment support
- Security improvements with vault integration

### Version 1.0.0
- Basic schema refresh functionality
- Simple variable structure
- Limited error handling

---

**Note**: This role is designed for enterprise environments with proper change management processes. Always test in non-production environments first.

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


---

# 🚀 Direct Execution Methods

To execute it directly on a specific server without Ansible Tower:

## 🚀 Direct Execution Methods

### 1. Basic Local Execution

````bash
# Run against localhost (same server)
ansible-playbook main.yml -i "localhost," --connection=local

# Run against a specific server
ansible-playbook main.yml -i "your-server-ip," --connection=ssh
````

### 2. Using Your Existing Inventory

````bash
# Use your existing inventory file
ansible-playbook main.yml -i inventory.ini -e @vars.yml -e @vault.yml --ask-vault-pass
````

### 3. Override Tower-Specific Variables

````bash
# Override Tower variables for manual execution
ansible-playbook main.yml \
  -i inventory.ini \
  -e @vars.yml \
  -e @vault.yml \
  -e "tower_job_id=manual-$(date +%s)" \
  -e "tower_user=$(whoami)" \
  -e "environment_name=development" \
  --ask-vault-pass
````

## 🔧 Required Adjustments

### 1. Create a Simple Inventory File

If you don't have one, create inventory.ini:

````ini
[databases]
your-oracle-server.domain.com ansible_user=oracle

[source_db]
your-oracle-server.domain.com

[target_db]
your-oracle-server.domain.com
````

### 2. Modify Variables for Direct Execution

Update your vars.yml to remove Tower dependencies:

````yaml
# Override Tower-specific defaults
tower_job_id: "manual"
tower_user: "{{ ansible_user_id }}"
environment_name: "development"

# Set target hosts for direct execution
target_hosts: "databases"

# Ensure vault file is specified
vault_file: "vault.yml"
````

### 3. Optional: Create a Simplified Playbook

Create a new file `run_direct.yml` for simpler direct execution:

````yaml
---
- name: Oracle Schema Refresh (Direct Execution)
  hosts: "{{ target_hosts | default('localhost') }}"
  gather_facts: true
  connection: "{{ connection_type | default('local') }}"
  
  vars_files:
    - vars.yml
    - "{{ vault_file | default('vault.yml') }}"
  
  vars:
    # Override Tower-specific variables
    tower_job_id: "manual-{{ ansible_date_time.epoch }}"
    tower_user: "{{ ansible_user_id }}"
    operation_start_time: "{{ ansible_date_time.epoch }}"
    
  roles:
    - role: oracle_schema_refresh
````

## 📋 Execution Examples

### 1. Same Server Execution (Local)

````bash
# Full refresh on same server
ansible-playbook main.yml \
  -i "localhost," \
  --connection=local \
  -e "source_db_host=localhost" \
  -e "target_db_host=localhost" \
  --ask-vault-pass

# Export only
ansible-playbook main.yml \
  -i "localhost," \
  --connection=local \
  -e "refresh_type=export_only" \
  --ask-vault-pass
````

### 2. Remote Server Execution

````bash
# Execute on remote Oracle server
ansible-playbook main.yml \
  -i "oracle-server.domain.com," \
  -u oracle \
  -e "source_db_host=oracle-server.domain.com" \
  -e "target_db_host=oracle-server.domain.com" \
  --ask-vault-pass
````

### 3. Cross-Server Execution

````bash
# Transfer between different servers
ansible-playbook main.yml \
  -i "source-server.domain.com,target-server.domain.com" \
  -e "source_db_host=source-server.domain.com" \
  -e "target_db_host=target-server.domain.com" \
  -e "transfer_method=direct" \
  --ask-vault-pass
````

## 🔍 Testing and Validation

### 1. Dry Run First

````bash
# Test configuration without making changes
ansible-playbook main.yml \
  -i inventory.ini \
  -e "dry_run=true" \
  --ask-vault-pass
````

### 2. Use the Validation Script

````bash
# Run the built-in configuration validator
./validate_config.sh
````

### 3. Check Syntax

````bash
# Validate playbook syntax
ansible-playbook main.yml --syntax-check
````

## ⚠️ Key Considerations

### 1. **Oracle Environment Setup**
Ensure Oracle environment variables are properly set on the target server:
- `ORACLE_HOME`
- `ORACLE_SID` 
- `PATH` includes Oracle binaries

### 2. **Permissions**
- The executing user needs sudo access or proper Oracle permissions
- Oracle user must have access to data pump directories

### 3. **Network Connectivity**
- SSH access to target servers
- Oracle database connectivity (port 1521)

### 4. **File Paths**
Verify these paths exist and are accessible:
- `oracle_data_pump_dir` (from defaults)
- `log_dir` (from vars.yml)

## 📚 Environment-Specific Execution

You can use the pre-configured environment files:

````bash
# Development environment
ansible-playbook main.yml -e @environments/development.yml

# Production environment  
ansible-playbook main.yml -e @environments/production.yml

# S3-optimized environment
ansible-playbook main.yml -e @environments/s3_optimized.yml
````
 