#!/usr/bin/env python3
import os
import sys
import subprocess
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
django.setup()

from django.db import connection
from tenants.models import Tenant
from django.contrib.auth import get_user_model

User = get_user_model()

def delete_tenant_records_raw():
    """Delete all tenants except public using raw SQL."""
    with connection.cursor() as cursor:
        cursor.execute("DELETE FROM tenants_tenant WHERE schema_name != 'public';")
    print("✅ All tenant records (except public) deleted via raw SQL.")

def drop_all_tenant_schemas():
    """Drop all schemas except public."""
    with connection.cursor() as cursor:
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

def create_tenant(schema_name='prod', name='Production Tenant', owner_username='admin'):
    owner = User.objects.filter(username=owner_username).first()
    if not owner:
        owner = User.objects.create_superuser(
            username=owner_username,
            password='admin123',
            email='admin@example.com'
        )
        print(f"👤 Created superuser '{owner_username}' with password 'admin123'.")
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
    cmd = ['python', 'manage.py', 'migrate_schemas']
    if schema_name:
        cmd.extend(['--schema', schema_name])
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
    print("🔧 Starting tenant fix (correct order)...")
    print("⚠️  This will delete ALL tenant records (except public) and drop ALL tenant schemas.")
    confirm = input("Type 'YES' to continue: ").strip()
    if confirm != 'YES':
        print("Aborted.")
        sys.exit(0)

    # 1. Delete tenant records first (avoids cascade issues)
    delete_tenant_records_raw()

    # 2. Drop all tenant schemas
    drop_all_tenant_schemas()

    # 3. Create a fresh tenant
    tenant = create_tenant(schema_name='prod', name='Production Tenant', owner_username='admin')

    # 4. Run migrations for this tenant
    run_migrate_schemas(schema_name=tenant.schema_name)

    print("🎉 Tenant setup complete! You can now access the portal.")
    print(f"   Login at: /portal/{tenant.schema_name}/")
    print("   Use superuser: admin / admin123 (change password later).")

if __name__ == '__main__':
    main()
