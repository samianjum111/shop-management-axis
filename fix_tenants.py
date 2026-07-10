#!/usr/bin/env python3
import os
import sys
import subprocess
import django
from django.conf import settings

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
django.setup()

from django.db import connection
from tenants.models import Tenant
from django.contrib.auth import get_user_model

User = get_user_model()

def run_sql(sql):
    """Execute raw SQL and print result."""
    with connection.cursor() as cursor:
        cursor.execute(sql)
        if cursor.description:
            return cursor.fetchall()
    return None

def drop_all_tenant_schemas():
    """Drop all schemas except 'public'."""
    with connection.cursor() as cursor:
        # Get list of all schemas
        cursor.execute("""
            SELECT schema_name
            FROM information_schema.schemata
            WHERE schema_name NOT IN ('public', 'information_schema', 'pg_catalog')
              AND schema_name NOT LIKE 'pg_%';
        """)
        schemas = [row[0] for row in cursor.fetchall()]
        for schema in schemas:
            print(f"🗑️  Dropping schema: {schema}")
            cursor.execute(f"DROP SCHEMA IF EXISTS {schema} CASCADE;")
    print("✅ All tenant schemas dropped.")

def delete_tenant_records():
    """Delete all tenant records except the public one."""
    # Ensure public tenant exists
    public_tenant, _ = Tenant.objects.get_or_create(
        schema_name='public',
        defaults={'name': 'Public Schema'}
    )
    # Delete all other tenants
    Tenant.objects.exclude(schema_name='public').delete()
    print("✅ Tenant records cleared (public kept).")

def create_tenant(schema_name='prod', name='Production Tenant', owner_username='admin'):
    """Create a new tenant with an existing superuser as owner."""
    owner = User.objects.filter(username=owner_username).first()
    if not owner:
        # If admin doesn't exist, create one (you can adjust)
        owner = User.objects.create_superuser(
            username=owner_username,
            password='admin123',  # Change this or prompt
            email='admin@example.com'
        )
        print(f"👤 Created superuser '{owner_username}' with password 'admin123' (change it later).")
    tenant, created = Tenant.objects.get_or_create(
        schema_name=schema_name,
        defaults={'name': name, 'owner': owner}
    )
    if created:
        print(f"✅ Tenant '{schema_name}' created.")
    else:
        print(f"ℹ️ Tenant '{schema_name}' already exists, reusing it.")
    return tenant

def run_migrate_schemas(schema_name=None):
    """Run migrate_schemas command with optional --schema."""
    cmd = ['python', 'manage.py', 'migrate_schemas']
    if schema_name:
        cmd.extend(['--schema', schema_name])
    # Add --noinput to avoid prompts
    cmd.append('--noinput')
    print(f"🔄 Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("❌ Migration failed:")
        print(result.stdout)
        print(result.stderr)
        sys.exit(1)
    else:
        print("✅ Migrations applied successfully.")
        print(result.stdout)

def main():
    print("🔧 Starting tenant fix...")
    # Backup warning
    print("⚠️  This script will DROP all tenant schemas and DELETE all tenant records (except public).")
    confirm = input("Type 'YES' to continue: ").strip()
    if confirm != 'YES':
        print("Aborted.")
        sys.exit(0)

    # Step 1: Drop schemas
    drop_all_tenant_schemas()

    # Step 2: Delete tenant records
    delete_tenant_records()

    # Step 3: Create a new tenant (prod)
    tenant = create_tenant(schema_name='prod', name='Production Tenant', owner_username='admin')

    # Step 4: Run migrate_schemas for this tenant
    run_migrate_schemas(schema_name=tenant.schema_name)

    print("🎉 Tenant setup complete! You can now access the portal.")
    print(f"   Login at: /portal/{tenant.schema_name}/")
    print("   Use the superuser credentials (admin/admin123) or your existing user.")

if __name__ == '__main__':
    main()
