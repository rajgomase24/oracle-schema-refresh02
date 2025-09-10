# AWS S3 Integration Setup Guide

This guide provides detailed instructions for setting up AWS S3 integration with the Oracle Schema Refresh automation.

## 🎯 Overview

The S3 integration provides enterprise-grade cloud storage for Oracle dump files with features including:
- Secure upload/download with encryption
- Lifecycle management for cost optimization
- Cross-region and cross-cloud transfer capabilities
- Audit trail and compliance features
- Automatic retry and error handling
- Fallback to direct transfer if needed

## 🛠️ Prerequisites

### AWS Requirements
- AWS Account with appropriate permissions
- S3 bucket (created automatically if it doesn't exist)
- IAM role or access keys for authentication

### System Requirements
- AWS CLI installed on Oracle servers
- Python boto3 library (for Ansible S3 modules)
- Network connectivity to AWS S3 endpoints

## 🔧 Setup Instructions

### 1. AWS Infrastructure Setup

#### Option A: Using IAM Roles (Recommended for EC2)

1. **Create IAM Policy for S3 Access**:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:GetObjectMetadata",
                "s3:PutObjectMetadata"
            ],
            "Resource": [
                "arn:aws:s3:::oracle-dumps-*",
                "arn:aws:s3:::oracle-dumps-*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:GetBucketVersioning",
                "s3:PutBucketVersioning",
                "s3:GetBucketLifecycleConfiguration",
                "s3:PutBucketLifecycleConfiguration"
            ],
            "Resource": "arn:aws:s3:::oracle-dumps-*"
        }
    ]
}
```

2. **Create IAM Role**:
```bash
# Create role
aws iam create-role \
  --role-name OracleSchemaRefreshRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach policy
aws iam attach-role-policy \
  --role-name OracleSchemaRefreshRole \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT:policy/OracleS3Policy

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name OracleSchemaRefreshProfile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name OracleSchemaRefreshProfile \
  --role-name OracleSchemaRefreshRole
```

3. **Attach Role to EC2 Instances**:
```bash
aws ec2 associate-iam-instance-profile \
  --instance-id i-1234567890abcdef0 \
  --iam-instance-profile Name=OracleSchemaRefreshProfile
```

#### Option B: Using Access Keys

1. **Create IAM User**:
```bash
aws iam create-user --user-name oracle-schema-refresh

# Attach policy
aws iam attach-user-policy \
  --user-name oracle-schema-refresh \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT:policy/OracleS3Policy

# Create access keys
aws iam create-access-key --user-name oracle-schema-refresh
```

2. **Store credentials in Ansible Vault**:
```bash
# Edit vault file
ansible-vault edit vault.yml

# Add credentials:
vault_s3_access_key_id: "AKIA_YOUR_ACCESS_KEY"
vault_s3_secret_access_key: "your_secret_access_key"
```

### 2. S3 Bucket Configuration

#### Create Buckets for Different Environments

```bash
# Development bucket
aws s3 mb s3://oracle-dumps-dev --region us-east-1

# Staging bucket
aws s3 mb s3://oracle-dumps-staging --region us-east-1

# Production bucket
aws s3 mb s3://oracle-dumps-prod --region us-east-1
```

#### Configure Bucket Policies

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyInsecureConnections",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::oracle-dumps-prod",
                "arn:aws:s3:::oracle-dumps-prod/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
```

#### Enable Versioning (Optional)

```bash
aws s3api put-bucket-versioning \
  --bucket oracle-dumps-prod \
  --versioning-configuration Status=Enabled
```

### 3. System Setup

#### Install AWS CLI on Oracle Servers

**RHEL/CentOS/Oracle Linux:**
```bash
# Download and install
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

**Amazon Linux:**
```bash
sudo yum install -y aws-cli
aws --version
```

#### Install Python Dependencies

```bash
# For Ansible S3 modules
sudo pip3 install boto3 botocore

# Verify installation
python3 -c "import boto3; print('boto3 version:', boto3.__version__)"
```

### 4. Ansible Configuration

#### Update Variables

**For IAM Role Authentication (Recommended):**
```yaml
# In vars.yml
transfer_method: "s3"
s3_use_iam_role: true
s3_bucket_name: "oracle-dumps-prod"
s3_bucket_region: "us-east-1"
```

**For Access Key Authentication:**
```yaml
# In vars.yml
transfer_method: "s3"
s3_use_iam_role: false
s3_bucket_name: "oracle-dumps-prod"
s3_bucket_region: "us-east-1"

# In vault.yml (encrypted)
vault_s3_access_key_id: "AKIA_YOUR_ACCESS_KEY"
vault_s3_secret_access_key: "your_secret_access_key"
```

## 🧪 Testing S3 Integration

### 1. Test AWS CLI Access

```bash
# Test basic access
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://oracle-dumps-dev --region us-east-1

# Test upload/download
echo "test" > test-file.txt
aws s3 cp test-file.txt s3://oracle-dumps-dev/test/
aws s3 rm s3://oracle-dumps-dev/test/test-file.txt
```

### 2. Test with Ansible

```bash
# Test S3 connectivity only
ansible-playbook main.yml \
  -e "transfer_method=s3" \
  -e "dry_run=true" \
  --tags s3,validation

# Test full S3 workflow in development
ansible-playbook main.yml \
  -e @environments/development.yml \
  -e "transfer_method=s3"
```

## 🔧 Configuration Examples

### Development Environment
```yaml
# environments/development.yml
transfer_method: "direct"  # Use direct for speed
enable_transfer_fallback: true
fallback_transfer_method: "s3"
s3_bucket_name: "oracle-dumps-dev"
s3_cleanup_after_success: true
```

### Production Environment
```yaml
# environments/production.yml
transfer_method: "s3"  # Use S3 for reliability
s3_bucket_name: "oracle-dumps-prod"
s3_storage_class: "STANDARD_IA"
s3_enable_lifecycle: true
s3_cleanup_after_success: false  # Keep for audit
enable_transfer_fallback: true
fallback_transfer_method: "direct"
```

### Cross-Region Setup
```yaml
# For cross-region transfers
s3_bucket_name: "oracle-dumps-global"
s3_bucket_region: "us-west-2"  # Different from EC2 region
transfer_method: "s3"
```

## 📊 Monitoring and Troubleshooting

### CloudWatch Metrics

Monitor S3 operations using CloudWatch:
- `NumberOfObjects`
- `BucketSizeBytes`
- `AllRequests`
- `GetRequests`
- `PutRequests`

### Common Issues and Solutions

#### 1. Permission Denied Errors
```bash
# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/OracleSchemaRefreshRole \
  --action-names s3:PutObject \
  --resource-arns arn:aws:s3:::oracle-dumps-prod/test-object
```

#### 2. Network Connectivity Issues
```bash
# Test S3 endpoint connectivity
telnet s3.us-east-1.amazonaws.com 443

# Check DNS resolution
nslookup s3.us-east-1.amazonaws.com

# Test with specific endpoint
aws s3 ls s3://oracle-dumps-prod --endpoint-url https://s3.us-east-1.amazonaws.com
```

#### 3. Large File Upload Issues
```bash
# Configure multipart settings
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 16MB
aws configure set default.s3.max_concurrent_requests 10
```

### Logging and Debugging

Enable detailed logging:
```yaml
# In vars.yml
detailed_logging: true
s3_max_attempts: 15
s3_retry_mode: "adaptive"
```

View logs:
```bash
# S3 transfer logs
tail -f /tmp/refresh_logs/s3_transfer_operations.log

# AWS CLI debug mode
aws s3 cp file.txt s3://bucket/key --debug
```

## 💰 Cost Optimization

### Storage Classes
- **STANDARD**: Immediate access, higher cost
- **STANDARD_IA**: Infrequent access, lower cost
- **GLACIER**: Archive storage, lowest cost
- **DEEP_ARCHIVE**: Long-term archive

### Lifecycle Policies
```yaml
# Optimize costs with lifecycle management
s3_enable_lifecycle: true
s3_lifecycle_days_to_ia: 30      # Move to IA after 30 days
s3_lifecycle_days_to_glacier: 90  # Move to Glacier after 90 days
s3_lifecycle_days_to_delete: 365  # Delete after 1 year
```

### Cost Monitoring
```bash
# Check bucket size and costs
aws s3api list-objects-v2 \
  --bucket oracle-dumps-prod \
  --query 'sum(Contents[].Size)' \
  --output text

# Use AWS Cost Explorer for detailed cost analysis
```

## 🔒 Security Best Practices

### 1. Encryption
```yaml
# Server-side encryption
s3_server_side_encryption: "AES256"  # or "aws:kms"
s3_kms_key_id: "arn:aws:kms:region:account:key/key-id"  # For KMS
```

### 2. Access Control
- Use IAM roles instead of access keys when possible
- Implement bucket policies for additional security
- Enable MFA for sensitive operations

### 3. Monitoring
- Enable CloudTrail for API logging
- Set up CloudWatch alarms for unusual activity
- Use S3 access logs for detailed monitoring

## 🚀 Advanced Features

### Cross-Account Access
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CrossAccountAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::OTHER-ACCOUNT:role/OracleSchemaRefreshRole"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::oracle-dumps-shared/*"
        }
    ]
}
```

### VPC Endpoints
For enhanced security and reduced data transfer costs:
```bash
# Create VPC endpoint for S3
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-12345678 \
  --service-name com.amazonaws.us-east-1.s3 \
  --policy-document file://s3-endpoint-policy.json
```

## 📞 Support and Troubleshooting

### Log Files to Check
- `/tmp/refresh_logs/s3_transfer_operations.log`
- `/tmp/refresh_logs/refresh_operations.log`
- AWS CloudTrail logs
- S3 access logs (if enabled)

### Useful Commands
```bash
# Check S3 configuration
aws s3api get-bucket-location --bucket oracle-dumps-prod

# List ongoing multipart uploads
aws s3api list-multipart-uploads --bucket oracle-dumps-prod

# Check object metadata
aws s3api head-object --bucket oracle-dumps-prod --key path/to/file.dmp
```

For additional support, contact the Database Automation Team or refer to the main README.md documentation.
