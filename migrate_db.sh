#!/bin/bash

# Database migration script from local EC2 PostgreSQL to RDS
# Source: Local PostgreSQL container
# Target: RDS PostgreSQL

echo "=== Starting database migration ==="

# Source database (local container)
SRC_HOST="localhost"
SRC_PORT="5433"
SRC_USER="postgres"
SRC_PASSWORD="postgres"
SRC_DB="bia"

# Target database (RDS)
TGT_HOST="bia.ctia5vvkqkpn.us-east-1.rds.amazonaws.com"
TGT_PORT="5432"
TGT_USER="postgres"
TGT_PASSWORD="btm7o8oteQuaJSqUJiRv"
TGT_DB="bia"

DUMP_FILE="/tmp/bia_migration_$(date +%Y%m%d_%H%M%S).sql"

echo "Step 1: Dumping data from local database..."
docker exec database pg_dump -U $SRC_USER -d $SRC_DB --data-only --inserts > $DUMP_FILE

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to dump data from local database"
    exit 1
fi

echo "Step 2: Restoring data to RDS..."
docker run --rm -i -e PGPASSWORD="$TGT_PASSWORD" postgres:17.1 psql -h $TGT_HOST -p $TGT_PORT -U $TGT_USER -d $TGT_DB < $DUMP_FILE

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to restore data to RDS"
    exit 1
fi

echo "Step 3: Verifying migration..."
echo "Local database row count:"
docker exec database psql -U $SRC_USER -d $SRC_DB -c "SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables ORDER BY tablename;"

echo ""
echo "RDS database row count:"
docker run --rm -e PGPASSWORD="$TGT_PASSWORD" postgres:17.1 psql -h $TGT_HOST -p $TGT_PORT -U $TGT_USER -d $TGT_DB -c "SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables ORDER BY tablename;"

echo ""
echo "=== Migration completed successfully ==="
echo "Dump file saved at: $DUMP_FILE"
