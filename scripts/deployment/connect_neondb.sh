#!/bin/bash

# =============================================================================
# NeonDB Database Connection Script
# =============================================================================
# 
# This script connects to the NeonDB PostgreSQL database using the provided
# connection string. It includes error handling and connection verification.
#
# Usage: ./connect_neondb.sh
# 
# Prerequisites:
# - PostgreSQL client (psql) must be installed
# - Network connectivity to NeonDB
# 
# Author: Generated for anesko project
# Date: $(date +%Y-%m-%d)
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Required environment variables for NeonDB connection
REQUIRED_ENV_VARS=("DB_HOST" "DB_USER" "DB_PASSWORD" "DB_NAME" "DB_SSL_MODE" "DB_CHANNEL_BINDING")

# Function to check if all required environment variables are set
check_env_vars() {
    log "Checking required environment variables..."

    local missing_vars=()
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please set these environment variables before running this script."
        echo "You can use the .env.template file as a reference:"
        echo "  1. Copy .env.template to .env: cp scripts/deployment/.env.template scripts/deployment/.env"
        echo "  2. Edit .env with your actual credentials"
        echo "  3. Source the environment: source scripts/deployment/.env"
        echo ""
        exit 1
    fi

    success "All required environment variables are set"
}

# Function to build NeonDB connection string from environment variables
build_connection_string() {
    NEONDB_CONNECTION_STRING="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}/${DB_NAME}?sslmode=${DB_SSL_MODE}&channel_binding=${DB_CHANNEL_BINDING}"
}

# Function to check if psql is installed
check_psql() {
    if ! command -v psql &> /dev/null; then
        error "PostgreSQL client (psql) is not installed."
        echo "Please install PostgreSQL client:"
        echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
        echo "  macOS: brew install postgresql"
        echo "  CentOS/RHEL: sudo yum install postgresql"
        exit 1
    fi
    log "PostgreSQL client found: $(psql --version)"
}

# Function to test database connection
test_connection() {
    log "Testing database connection..."
    
    if psql "$NEONDB_CONNECTION_STRING" -c "SELECT 1;" &> /dev/null; then
        success "Database connection successful!"
        return 0
    else
        error "Failed to connect to database"
        return 1
    fi
}

# Function to connect to database interactively
connect_interactive() {
    log "Connecting to NeonDB database..."
    log "Connection details:"
    echo "  Host: ${DB_HOST}"
    echo "  Database: ${DB_NAME}"
    echo "  User: ${DB_USER}"
    echo "  SSL Mode: ${DB_SSL_MODE}"
    echo "  Channel Binding: ${DB_CHANNEL_BINDING}"
    echo ""

    # Connect to database
    psql "$NEONDB_CONNECTION_STRING"
}

# Function to execute a SQL command
execute_sql() {
    local sql_command="$1"
    log "Executing SQL command: $sql_command"
    
    psql "$NEONDB_CONNECTION_STRING" -c "$sql_command"
}

# Function to show database information
show_db_info() {
    log "Retrieving database information..."
    
    echo ""
    echo "=== Database Information ==="
    psql "$NEONDB_CONNECTION_STRING" -c "
        SELECT 
            current_database() as database_name,
            current_user as current_user,
            version() as postgresql_version;
    "
    
    echo ""
    echo "=== Available Tables ==="
    psql "$NEONDB_CONNECTION_STRING" -c "
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename;
    "
}

# Main function
main() {
    log "Starting NeonDB connection script..."

    # Check prerequisites
    check_env_vars
    build_connection_string
    check_psql
    
    # Parse command line arguments
    case "${1:-interactive}" in
        "test")
            test_connection
            ;;
        "info")
            show_db_info
            ;;
        "sql")
            if [ -z "${2:-}" ]; then
                error "SQL command required. Usage: $0 sql 'SELECT * FROM table;'"
                exit 1
            fi
            execute_sql "$2"
            ;;
        "interactive"|"")
            if test_connection; then
                connect_interactive
            else
                error "Connection test failed. Please check your network connection and credentials."
                exit 1
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  interactive  Connect to database interactively (default)"
            echo "  test         Test database connection"
            echo "  info         Show database information"
            echo "  sql 'CMD'    Execute SQL command"
            echo "  help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Interactive connection"
            echo "  $0 test                      # Test connection"
            echo "  $0 info                      # Show database info"
            echo "  $0 sql 'SELECT NOW();'       # Execute SQL command"
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
