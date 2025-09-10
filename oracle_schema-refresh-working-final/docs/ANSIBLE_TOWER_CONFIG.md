# =============================================================================
# Ansible Tower Configuration Guide
# Oracle Schema Refresh Role
# =============================================================================

## Job Template Configuration

### Basic Settings
- **Name**: Oracle Schema Refresh
- **Job Type**: Run
- **Inventory**: Oracle Database Servers
- **Project**: Oracle Automation
- **Playbook**: main.yml
- **Credential Types Required**:
  - Machine Credential (SSH access to Oracle servers)
  - Custom Credential (Oracle Database passwords)

### Variables Configuration

#### Default Extra Variables (JSON format):
```json
{
  "environment_name": "development",
  "refresh_type": "full",
  "transfer_method": "direct",
  "validation_required": true,
  "detailed_logging": true,
  "parallel_threads": 4,
  "enable_preflight_checks": true,
  "cleanup_dump_files": false,
  "s3_bucket_name": "oracle-dumps-dev",
  "s3_bucket_region": "us-east-1",
  "s3_use_iam_role": true
}
```

## Survey Configuration

### Survey Questions for Dynamic Input:

#### 1. Environment Selection
- **Variable Name**: `environment_name`
- **Question**: "Select Target Environment"
- **Answer Type**: Multiple Choice (single select)
- **Choices**:
  - development
  - testing
  - staging
  - production
- **Default**: development
- **Required**: Yes

#### 2. Refresh Type
- **Variable Name**: `refresh_type`
- **Question**: "Select Refresh Operation Type"
- **Answer Type**: Multiple Choice (single select)
- **Choices**:
  - full
  - export_only
  - import_only
- **Default**: full
- **Required**: Yes

#### 3. Transfer Method
- **Variable Name**: `transfer_method`
- **Question**: "Select Transfer Method"
- **Answer Type**: Multiple Choice (single select)
- **Choices**:
  - direct
  - s3
  - hybrid
- **Default**: direct
- **Required**: Yes

#### 3. Source Schema
- **Variable Name**: `source_schema`
- **Question**: "Source Schema Name"
- **Answer Type**: Text
- **Default**: AUTOMATIONTEST
- **Required**: Yes
- **Min/Max Length**: 1/30

#### 4. Target Schema
- **Variable Name**: `target_schema`
- **Question**: "Target Schema Name"
- **Answer Type**: Text
- **Default**: AUTOMATIONTEST
- **Required**: Yes
- **Min/Max Length**: 1/30

#### 5. Source Database Service
- **Variable Name**: `source_db_service`
- **Question**: "Source Database Service Name"
- **Answer Type**: Text
- **Default**: nsqual01
- **Required**: Yes

#### 6. Target Database Service
- **Variable Name**: `target_db_service`
- **Question**: "Target Database Service Name"
- **Answer Type**: Text
- **Default**: nsqual01
- **Required**: Yes

#### 7. Validation Required
- **Variable Name**: `validation_required`
- **Question**: "Run Post-Refresh Validation?"
- **Answer Type**: Multiple Choice (single select)
- **Choices**:
  - true
  - false
- **Default**: true
- **Required**: Yes

#### 8. Parallel Threads
- **Variable Name**: `parallel_threads`
- **Question**: "Number of Parallel Threads (1-8)"
- **Answer Type**: Integer
- **Default**: 4
- **Min/Max**: 1/8
- **Required**: Yes

#### 9. Cleanup Dump Files
- **Variable Name**: `cleanup_dump_files`
- **Question**: "Delete dump files after successful import?"
- **Answer Type**: Multiple Choice (single select)
- **Choices**:
  - true
  - false
- **Default**: false
- **Required**: No

#### 10. S3 Bucket Name (Conditional)
- **Variable Name**: `s3_bucket_name`
- **Question**: "S3 Bucket Name (for S3/Hybrid transfers)"
- **Answer Type**: Text
- **Default**: oracle-dumps-dev
- **Required**: No
- **Min/Max Length**: 3/63

#### 11. S3 Region (Conditional)
- **Variable Name**: `s3_bucket_region`
- **Question**: "S3 Bucket Region"
- **Answer Type**: Multiple Choice (single select)
- **Choices**:
  - us-east-1
  - us-west-2
  - eu-west-1
  - ap-southeast-1
- **Default**: us-east-1
- **Required**: No

#### 12. Advanced Options Toggle
- **Variable Name**: `show_advanced_options`
- **Question**: "Show Advanced Configuration Options?"
- **Answer Type**: Multiple Choice (single select)
- **Choices**:
  - true
  - false
- **Default**: false
- **Required**: No

## Custom Credential Type Configuration

### Oracle Database Credential Type:

#### Input Configuration:
```yaml
fields:
  - id: db_username
    type: string
    label: Database Username
    help_text: Administrative database user (e.g., testdba)
  - id: db_password
    type: string
    label: Database Password
    secret: true
    help_text: Password for the database user
  - id: sys_password
    type: string
    label: SYS Password
    secret: true
    help_text: SYS user password for administrative operations
required:
  - db_username
  - db_password
  - sys_password
```

#### Injector Configuration:
```yaml
extra_vars:
  db_user: "{{ db_username }}"
  vault_db_password: "{{ db_password }}"
  vault_sys_password: "{{ sys_password }}"
```

### AWS S3 Credential Type:

#### Input Configuration:
```yaml
fields:
  - id: aws_access_key_id
    type: string
    label: AWS Access Key ID
    help_text: AWS Access Key ID for S3 operations
  - id: aws_secret_access_key
    type: string
    label: AWS Secret Access Key
    secret: true
    help_text: AWS Secret Access Key for S3 operations
  - id: aws_session_token
    type: string
    label: AWS Session Token
    secret: true
    help_text: AWS Session Token (for temporary credentials)
    ask_at_runtime: false
  - id: aws_region
    type: string
    label: Default AWS Region
    help_text: Default AWS region for S3 operations
    default: us-east-1
required:
  - aws_access_key_id
  - aws_secret_access_key
```

#### Injector Configuration:
```yaml
extra_vars:
  vault_s3_access_key_id: "{{ aws_access_key_id }}"
  vault_s3_secret_access_key: "{{ aws_secret_access_key }}"
  vault_s3_session_token: "{{ aws_session_token }}"
  s3_bucket_region: "{{ aws_region }}"
env:
  AWS_ACCESS_KEY_ID: "{{ aws_access_key_id }}"
  AWS_SECRET_ACCESS_KEY: "{{ aws_secret_access_key }}"
  AWS_SESSION_TOKEN: "{{ aws_session_token }}"
  AWS_DEFAULT_REGION: "{{ aws_region }}"
```

## Workflow Template Configuration

### Multi-Environment Workflow:

#### 1. Pre-Flight Validation Job
- **Job Template**: Oracle Pre-Flight Check
- **Variables**: 
  ```json
  {
    "refresh_type": "validation_only",
    "enable_preflight_checks": true,
    "dry_run": true
  }
  ```

#### 2. Export Job (Conditional)
- **Job Template**: Oracle Schema Export
- **Condition**: `refresh_type in ['full', 'export_only']`
- **Variables**:
  ```json
  {
    "refresh_type": "export_only"
  }
  ```

#### 3. Import Job (Conditional)
- **Job Template**: Oracle Schema Import
- **Condition**: `refresh_type in ['full', 'import_only']`
- **Variables**:
  ```json
  {
    "refresh_type": "import_only"
  }
  ```

#### 4. Validation Job
- **Job Template**: Oracle Schema Validation
- **Condition**: `validation_required == true`
- **Variables**:
  ```json
  {
    "validation_required": true,
    "refresh_type": "validation_only"
  }
  ```

## Notifications Configuration

### Email Notifications:
- **Success**: Send to DBA team and requestor
- **Failure**: Send to DBA team and on-call
- **Always**: Send summary to audit team

### Slack/Teams Integration:
```json
{
  "success_webhook": "https://hooks.slack.com/services/YOUR/SUCCESS/WEBHOOK",
  "failure_webhook": "https://hooks.slack.com/services/YOUR/FAILURE/WEBHOOK",
  "channel": "#oracle-automation"
}
```

## Access Control (RBAC)

### Role Definitions:

#### DBA Admin
- **Permissions**: 
  - Execute any refresh type
  - Access production environments
  - Modify advanced settings
  - View all logs and reports

#### Developer
- **Permissions**:
  - Execute development/testing refreshes only
  - Limited to non-production environments
  - Cannot modify security settings

#### Read-Only Auditor
- **Permissions**:
  - View job execution history
  - Access reports and logs
  - No execution permissions

## Environment-Specific Configurations

### Development Environment:
```json
{
  "environment_name": "development",
  "backup_before_drop": false,
  "cleanup_dump_files": true,
  "detailed_logging": true,
  "schema_existence_check": "warn"
}
```

### Production Environment:
```json
{
  "environment_name": "production",
  "backup_before_drop": true,
  "cleanup_dump_files": false,
  "detailed_logging": true,
  "schema_existence_check": "strict",
  "enable_preflight_checks": true,
  "validation_required": true
}
```

## Monitoring and Logging

### Log Aggregation:
- Configure Tower to collect logs from: `/tmp/refresh_logs/`
- Set up log rotation and archival policies
- Integrate with centralized logging (ELK, Splunk, etc.)

### Metrics Collection:
- Track job execution times
- Monitor success/failure rates
- Alert on unusual patterns

### Dashboards:
- Real-time job status
- Historical performance trends
- Resource utilization metrics

## Backup and Recovery

### Job Template Backup:
- Export job templates regularly
- Version control configuration changes
- Document custom credential types

### Recovery Procedures:
- Rollback procedures for failed refreshes
- Schema recovery from backups
- Data consistency verification steps

## Security Best Practices

### Credential Management:
- Use Tower credential system, never hardcode passwords
- Rotate credentials regularly
- Implement principle of least privilege

### Network Security:
- Use SSH key authentication
- Implement network segmentation
- Monitor access logs

### Audit Trail:
- Enable comprehensive job logging
- Track all configuration changes
- Maintain access control audit logs

## Troubleshooting Guide

### Common Issues:

#### Connection Failures:
1. Verify SSH connectivity to Oracle servers
2. Check Oracle listener status
3. Validate database service names

#### Permission Errors:
1. Verify oracle user permissions
2. Check Data Pump directory access
3. Validate sudoers configuration

#### Performance Issues:
1. Adjust parallel thread count
2. Monitor disk I/O and space
3. Review Oracle database performance

### Support Contacts:
- **DBA Team**: dba-team@company.com
- **Automation Team**: automation@company.com
- **Emergency**: on-call-dba@company.com

## Updates and Maintenance

### Regular Tasks:
- Review and update default variables
- Test job templates after Tower upgrades
- Update documentation and procedures

### Change Management:
- All changes require approval
- Test in development first
- Maintain rollback procedures

---

For additional support or questions about this configuration, please contact the Database Automation Team.
