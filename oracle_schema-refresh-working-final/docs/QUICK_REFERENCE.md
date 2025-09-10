# Oracle Schema Refresh - Quick Reference Guide

## 🚀 Quick Commands

### Basic Operations
```bash
# Full refresh (export + import + validation)
ansible-playbook main.yml

# Export only
ansible-playbook main.yml -e "refresh_type=export_only"

# Import only (assumes dump file exists)
ansible-playbook main.yml -e "refresh_type=import_only"

# Dry run (validate without executing)
ansible-playbook main.yml -e "dry_run=true"
```

### Transfer Method Options
```bash
# Direct server-to-server transfer (default)
ansible-playbook main.yml -e "transfer_method=direct"

# S3-based transfer
ansible-playbook main.yml -e "transfer_method=s3"

# Hybrid (upload to S3, keep local copy)
ansible-playbook main.yml -e "transfer_method=hybrid"

# S3 with custom bucket
ansible-playbook main.yml -e "transfer_method=s3" -e "s3_bucket_name=my-oracle-dumps"
```

### Environment-Specific Runs
```bash
# Development environment (direct transfer)
ansible-playbook main.yml -e @environments/development.yml

# Production environment (S3 transfer)
ansible-playbook main.yml -e @environments/production.yml

# S3-optimized environment
ansible-playbook main.yml -e @environments/s3_optimized.yml

# Custom environment variables
ansible-playbook main.yml -e "source_schema=PROD_DATA" -e "target_schema=TEST_DATA"
```

### With Vault
```bash
# Using vault file
ansible-playbook main.yml --ask-vault-pass

# With vault password file
ansible-playbook main.yml --vault-password-file .vault_pass
```

## 📋 Key Variables Quick Reference

### Most Common Overrides
```yaml
source_schema: "YOUR_SOURCE_SCHEMA"
target_schema: "YOUR_TARGET_SCHEMA"
refresh_type: "full"                    # full|export_only|import_only
transfer_method: "direct"               # direct|s3|hybrid
parallel_threads: 4                     # 1-8
validation_required: true               # true|false
environment_name: "development"         # development|testing|staging|production
```

### S3 Configuration
```yaml
s3_bucket_name: "oracle-dumps"
s3_bucket_region: "us-east-1"           # AWS region
s3_storage_class: "STANDARD_IA"         # STANDARD|STANDARD_IA|GLACIER
s3_use_iam_role: true                   # true|false
s3_cleanup_after_success: false         # true|false
enable_transfer_fallback: true          # true|false
```

### Database Connection
```yaml
source_db_host: "source-server.company.com"
target_db_host: "target-server.company.com"
source_db_service: "sourcedb01"
target_db_service: "targetdb01"
db_user: "your_db_user"
```

### Oracle Environment
```yaml
oracle_home: "/u01/app/oracle/product/19c/dbhome_1"
oracle_user: "oracle"
oracle_data_pump_dir: "/u01/app/oracle/admin/DBSID/dpdump"
```

## 🔧 Troubleshooting Quick Fixes

### Permission Issues
```bash
# Fix log directory permissions
sudo mkdir -p /tmp/refresh_logs
sudo chown oracle:oracle /tmp/refresh_logs

# Fix Oracle Data Pump directory
sudo chown oracle:oracle /u01/app/oracle/admin/*/dpdump

# Check AWS CLI permissions (for S3 transfers)
aws s3 ls s3://your-bucket-name --region us-east-1
```

### Connection Issues
```bash
# Test Oracle connectivity
sqlplus username/password@host:port/service

# Test SSH connectivity
ssh oracle@target-server

# Test S3 connectivity
aws s3 ls s3://your-bucket-name --region us-east-1

# Test AWS credentials
aws sts get-caller-identity
```

### S3-Specific Issues
```bash
# Check S3 bucket exists
aws s3 ls s3://your-bucket-name --region us-east-1

# List objects in bucket
aws s3 ls s3://your-bucket-name/oracle-schema-refresh/ --recursive

# Check S3 object metadata
aws s3api head-object --bucket your-bucket-name --key path/to/your/file.dmp

# Manual S3 upload test
aws s3 cp test-file.txt s3://your-bucket-name/test/ --region us-east-1

# Check S3 permissions
aws s3api get-bucket-acl --bucket your-bucket-name --region us-east-1
```

### Space Issues
```bash
# Check available space
df -h /u01/app/oracle/admin/*/dpdump

# Clean old dump files
find /u01/app/oracle/admin/*/dpdump -name "*.dmp" -mtime +7 -delete
```

## 🏢 Ansible Tower Quick Setup

### Job Template Variables
```json
{
  "environment_name": "development",
  "refresh_type": "full",
  "validation_required": true,
  "parallel_threads": 4,
  "detailed_logging": true
}
```

### Survey Questions (Key Ones)
- **Environment**: Choice (development, testing, staging, production)
- **Operation Type**: Choice (full, export_only, import_only)
- **Source Schema**: Text input
- **Target Schema**: Text input
- **Parallel Threads**: Integer (1-8)

## 📊 Monitoring Commands

### During Execution
```bash
# Monitor logs
tail -f /tmp/refresh_logs/refresh_operations.log

# Monitor S3 transfer logs (if using S3)
tail -f /tmp/refresh_logs/s3_transfer_operations.log

# Monitor Oracle sessions
sqlplus / as sysdba
SELECT username, status, machine FROM v$session WHERE username = 'YOUR_SCHEMA';

# Monitor Data Pump jobs
SELECT job_name, state, degree FROM dba_datapump_jobs;

# Monitor disk space
watch "df -h /u01/app/oracle/admin/*/dpdump"

# Monitor S3 uploads/downloads
aws s3api list-multipart-uploads --bucket your-bucket-name --region us-east-1

# Check S3 transfer progress (if using AWS CLI with progress)
watch "aws s3 ls s3://your-bucket-name/path/ --recursive --human-readable"
```

### Post-Execution Validation
```bash
# Check object counts
sqlplus username/password@host:port/service
SELECT COUNT(*) FROM all_objects WHERE owner = 'TARGET_SCHEMA';

# Check table counts
SELECT COUNT(*) FROM all_tables WHERE owner = 'TARGET_SCHEMA';

# Check for invalid objects
SELECT COUNT(*) FROM all_objects WHERE owner = 'TARGET_SCHEMA' AND status = 'INVALID';
```

## 🔒 Security Quick Reference

### Vault Operations
```bash
# Create new vault file
ansible-vault create vault.yml

# Edit existing vault
ansible-vault edit vault.yml

# View vault contents
ansible-vault view vault.yml

# Change vault password
ansible-vault rekey vault.yml
```

### Credential Variables
```yaml
# In vault.yml (encrypted)
vault_db_password: "secure_password"
vault_sys_password: "secure_sys_password"

# In vars.yml (references vault)
db_password: "{{ vault_db_password }}"
sys_password: "{{ vault_sys_password }}"
```

## ⚡ Performance Tuning

### For Large Schemas
```yaml
parallel_threads: 8
dump_compression: "ALL"
datapump_operation_timeout: 14400  # 4 hours
```

### For Small Schemas
```yaml
parallel_threads: 2
dump_compression: "NONE"
datapump_operation_timeout: 1800   # 30 minutes
```

### Network Optimization
```yaml
transfer_retry_count: 5
transfer_retry_delay: 30
```

## 🆘 Emergency Procedures

### Stop Running Operations
```bash
# Find Data Pump jobs
sqlplus / as sysdba
SELECT job_name FROM dba_datapump_jobs WHERE state = 'EXECUTING';

# Stop specific job
EXEC DBMS_DATAPUMP.STOP_JOB('JOB_NAME');

# Kill Ansible process
ps aux | grep ansible-playbook
kill -TERM <process_id>
```

### Rollback Failed Import
```bash
# Drop corrupted schema
sqlplus / as sysdba
DROP USER target_schema CASCADE;

# Restore from backup (if backup_before_drop was enabled)
impdp username/password directory=DATA_PUMP_DIR dumpfile=backup_*.dmp
```

### Emergency Contacts
- **DBA Team**: dba-team@company.com
- **Automation Team**: automation@company.com
- **On-Call**: +1-555-ORACLE-911

---

**💡 Tip**: Keep this guide handy during operations. For detailed explanations, refer to the main README.md file.
