#!/bin/bash
# =============================================================================
# Oracle Schema Refresh - Configuration Validation Script
# =============================================================================
# This script validates the Ansible configuration and Oracle environment
# before running schema refresh operations.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/oracle_refresh_validation.log"

# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARNING: $1"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log "ERROR: $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 is available"
        return 0
    else
        print_error "$1 is not available"
        return 1
    fi
}

validate_file() {
    if [[ -f "$1" ]]; then
        print_success "File exists: $1"
        return 0
    else
        print_error "File missing: $1"
        return 1
    fi
}

validate_directory() {
    if [[ -d "$1" ]]; then
        print_success "Directory exists: $1"
        return 0
    else
        print_error "Directory missing: $1"
        return 1
    fi
}

# Start validation
print_header "Oracle Schema Refresh - Configuration Validation"
log "Starting validation process"

ERRORS=0

# 1. Check Ansible installation
print_header "1. Ansible Environment Validation"

if check_command "ansible"; then
    ANSIBLE_VERSION=$(ansible --version | head -n1 | awk '{print $2}')
    echo "Ansible Version: $ANSIBLE_VERSION"
    
    # Check if version is 2.9 or higher
    if [[ $(echo "$ANSIBLE_VERSION 2.9.0" | tr " " "\n" | sort -V | head -n1) == "2.9.0" ]]; then
        print_success "Ansible version ($ANSIBLE_VERSION) meets requirements (>= 2.9.0)"
    else
        print_error "Ansible version ($ANSIBLE_VERSION) is below requirements (>= 2.9.0)"
        ((ERRORS++))
    fi
else
    ((ERRORS++))
fi

if check_command "ansible-playbook"; then
    print_success "ansible-playbook command available"
else
    ((ERRORS++))
fi

if check_command "ansible-vault"; then
    print_success "ansible-vault command available"
else
    ((ERRORS++))
fi

# 2. Check file structure
print_header "2. File Structure Validation"

# Core files
validate_file "$SCRIPT_DIR/main.yml" || ((ERRORS++))
validate_file "$SCRIPT_DIR/vars.yml" || ((ERRORS++))
validate_file "$SCRIPT_DIR/vault.yml" || ((ERRORS++))
validate_file "$SCRIPT_DIR/inventory.ini" || ((ERRORS++))

# Role structure
validate_directory "$SCRIPT_DIR/oracle_schema_refresh" || ((ERRORS++))
validate_file "$SCRIPT_DIR/oracle_schema_refresh/defaults/main.yml" || ((ERRORS++))
validate_directory "$SCRIPT_DIR/oracle_schema_refresh/tasks" || ((ERRORS++))
validate_file "$SCRIPT_DIR/oracle_schema_refresh/tasks/main.yml" || ((ERRORS++))
validate_file "$SCRIPT_DIR/oracle_schema_refresh/tasks/export_schema.yml" || ((ERRORS++))
validate_file "$SCRIPT_DIR/oracle_schema_refresh/tasks/import_schema.yml" || ((ERRORS++))
validate_file "$SCRIPT_DIR/oracle_schema_refresh/tasks/drop_target_schema.yml" || ((ERRORS++))
validate_file "$SCRIPT_DIR/oracle_schema_refresh/tasks/transfer_dump.yml" || ((ERRORS++))

# Documentation
validate_file "$SCRIPT_DIR/README.md" || ((ERRORS++))
validate_file "$SCRIPT_DIR/ANSIBLE_TOWER_CONFIG.md" || ((ERRORS++))

# Environment configurations
validate_directory "$SCRIPT_DIR/environments" || ((ERRORS++))
validate_file "$SCRIPT_DIR/environments/development.yml" || ((ERRORS++))
validate_file "$SCRIPT_DIR/environments/production.yml" || ((ERRORS++))

# 3. YAML syntax validation
print_header "3. YAML Syntax Validation"

yaml_files=(
    "main.yml"
    "vars.yml"
    "inventory.ini"
    "oracle_schema_refresh/defaults/main.yml"
    "oracle_schema_refresh/tasks/main.yml"
    "oracle_schema_refresh/tasks/export_schema.yml"
    "oracle_schema_refresh/tasks/import_schema.yml"
    "oracle_schema_refresh/tasks/drop_target_schema.yml"
    "oracle_schema_refresh/tasks/transfer_dump.yml"
    "environments/development.yml"
    "environments/production.yml"
)

for yaml_file in "${yaml_files[@]}"; do
    full_path="$SCRIPT_DIR/$yaml_file"
    if [[ -f "$full_path" ]]; then
        if ansible-playbook --syntax-check --list-tasks "$full_path" &>/dev/null 2>&1 || \
           python3 -c "import yaml; yaml.safe_load(open('$full_path'))" &>/dev/null; then
            print_success "YAML syntax valid: $yaml_file"
        else
            print_error "YAML syntax error in: $yaml_file"
            ((ERRORS++))
        fi
    fi
done

# 4. Variable consistency check
print_header "4. Variable Consistency Validation"

# Check if all required variables are defined
required_vars=(
    "source_db_host"
    "target_db_host"
    "source_schema"
    "target_schema"
    "db_user"
    "oracle_home"
    "oracle_user"
    "dump_dir"
    "dump_file_name"
    "refresh_type"
)

vars_file="$SCRIPT_DIR/vars.yml"
if [[ -f "$vars_file" ]]; then
    for var in "${required_vars[@]}"; do
        if grep -q "^$var:" "$vars_file"; then
            print_success "Required variable defined: $var"
        else
            print_error "Required variable missing: $var"
            ((ERRORS++))
        fi
    done
else
    print_error "vars.yml file not found"
    ((ERRORS++))
fi

# 5. Inventory validation
print_header "5. Inventory Validation"

inventory_file="$SCRIPT_DIR/inventory.ini"
if [[ -f "$inventory_file" ]]; then
    if ansible-inventory -i "$inventory_file" --list &>/dev/null; then
        print_success "Inventory file syntax is valid"
        
        # Check for required groups
        if ansible-inventory -i "$inventory_file" --list | grep -q "databases\|source_db\|target_db"; then
            print_success "Required inventory groups found"
        else
            print_warning "Standard inventory groups (databases, source_db, target_db) not found"
        fi
    else
        print_error "Inventory file syntax error"
        ((ERRORS++))
    fi
else
    print_error "Inventory file not found"
    ((ERRORS++))
fi

# 6. Oracle environment check (if running on Oracle server)
print_header "6. Oracle Environment Check"

if check_command "sqlplus"; then
    print_success "SQL*Plus is available"
    
    if check_command "expdp"; then
        print_success "Oracle Data Pump Export (expdp) is available"
    else
        print_warning "Oracle Data Pump Export (expdp) not found in PATH"
    fi
    
    if check_command "impdp"; then
        print_success "Oracle Data Pump Import (impdp) is available"
    else
        print_warning "Oracle Data Pump Import (impdp) not found in PATH"
    fi
    
    # Check Oracle environment variables
    if [[ -n "${ORACLE_HOME:-}" ]]; then
        print_success "ORACLE_HOME is set: $ORACLE_HOME"
        
        if [[ -d "$ORACLE_HOME" ]]; then
            print_success "ORACLE_HOME directory exists"
        else
            print_error "ORACLE_HOME directory does not exist: $ORACLE_HOME"
            ((ERRORS++))
        fi
    else
        print_warning "ORACLE_HOME environment variable not set"
    fi
    
    if [[ -n "${ORACLE_SID:-}" ]]; then
        print_success "ORACLE_SID is set: $ORACLE_SID"
    else
        print_warning "ORACLE_SID environment variable not set"
    fi
    
else
    print_warning "SQL*Plus not found - Oracle environment validation skipped"
fi

# 7. Python and system dependencies
print_header "7. System Dependencies Check"

if check_command "python3"; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    print_success "Python 3 available: $PYTHON_VERSION"
else
    print_warning "Python 3 not found"
fi

if check_command "ssh"; then
    print_success "SSH client available"
else
    print_error "SSH client not found"
    ((ERRORS++))
fi

if check_command "rsync"; then
    print_success "rsync available (needed for file transfers)"
else
    print_warning "rsync not found - file transfers between servers may fail"
fi

# 8. Permissions check
print_header "8. Permissions Validation"

# Check if we can write to log directory
log_dir="/tmp/refresh_logs"
if mkdir -p "$log_dir" 2>/dev/null; then
    if touch "$log_dir/test_write" 2>/dev/null; then
        print_success "Can write to log directory: $log_dir"
        rm -f "$log_dir/test_write"
    else
        print_error "Cannot write to log directory: $log_dir"
        ((ERRORS++))
    fi
else
    print_error "Cannot create log directory: $log_dir"
    ((ERRORS++))
fi

# 9. Vault file check
print_header "9. Vault Configuration Check"

vault_file="$SCRIPT_DIR/vault.yml"
if [[ -f "$vault_file" ]]; then
    if ansible-vault view "$vault_file" --ask-vault-pass &>/dev/null; then
        print_success "Vault file is properly encrypted and accessible"
    else
        print_warning "Vault file exists but may have encryption issues"
    fi
else
    print_warning "Vault file not found - ensure passwords are configured"
fi

# 10. Ansible Tower compatibility check
print_header "10. Ansible Tower Compatibility Check"

# Check for Tower-specific configurations
tower_config_file="$SCRIPT_DIR/ANSIBLE_TOWER_CONFIG.md"
if [[ -f "$tower_config_file" ]]; then
    print_success "Ansible Tower configuration documentation found"
else
    print_warning "Ansible Tower configuration documentation missing"
fi

# Check for survey-compatible variables
survey_vars=("environment_name" "refresh_type" "validation_required")
for var in "${survey_vars[@]}"; do
    if grep -q "$var:" "$vars_file" 2>/dev/null; then
        print_success "Survey-compatible variable found: $var"
    else
        print_warning "Survey-compatible variable missing: $var"
    fi
done

# Summary
print_header "Validation Summary"

if [[ $ERRORS -eq 0 ]]; then
    print_success "All critical validations passed! ✅"
    echo ""
    echo -e "${GREEN}Your Oracle Schema Refresh configuration is ready to use.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test with dry run: ansible-playbook main.yml -e 'dry_run=true'"
    echo "2. Run in development: ansible-playbook main.yml -e @environments/development.yml"
    echo "3. Configure Ansible Tower using ANSIBLE_TOWER_CONFIG.md"
    
    exit 0
else
    print_error "Validation completed with $ERRORS critical errors"
    echo ""
    echo -e "${RED}Please fix the errors above before proceeding.${NC}"
    echo ""
    echo "Common fixes:"
    echo "1. Install missing packages: ansible, python3, oracle-client"
    echo "2. Fix YAML syntax errors in configuration files"
    echo "3. Ensure proper file permissions and directory structure"
    echo "4. Configure Oracle environment variables"
    
    exit 1
fi
