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

def run_sql(sql):
    with connection.cursor() as cursor:
        cursor.execute(sql)
        return cursor.fetchall() if cursor.description else None

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

def delete_all_tenant_records():
    """Delete all tenants except public using raw SQL."""
    with connection.cursor() as cursor:
        cursor.execute("DELETE FROM tenants_tenant WHERE schema_name != 'public';")
    print("✅ All tenant records (except public) deleted.")

def create_tenant(schema_name, name, owner_username='admin'):
    """Create a new tenant with an existing superuser as owner."""
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

def create_schema(schema_name):
    """Create the schema if it doesn't exist (empty)."""
    with connection.cursor() as cursor:
        cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema_name};")
    print(f"✅ Schema '{schema_name}' created (or already exists).")

def run_migrate_schemas(schema_name):
    """Run migrate_schemas for the given schema."""
    cmd = ['python', 'manage.py', 'migrate_schemas', '--schema', schema_name, '--noinput']
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
    print("🔧 Starting final tenant fix...")
    print("⚠️  This will DELETE all tenant records and DROP all tenant schemas (except public).")
    confirm = input("Type 'YES' to continue: ").strip()
    if confirm != 'YES':
        print("Aborted.")
        sys.exit(0)

    # 1. Delete tenant records (to avoid cascade issues)
    delete_all_tenant_records()

    # 2. Drop all tenant schemas
    drop_all_tenant_schemas()

    # 3. Create a new tenant (use a distinct schema name)
    schema_name = 'prod_fresh'  # change if you prefer
    tenant = create_tenant(schema_name, 'Production Tenant')

    # 4. Create the schema manually (empty)
    create_schema(schema_name)

    # 5. Run migrations for this schema
    run_migrate_schemas(schema_name)

    print("🎉 Tenant setup complete!")
    print(f"   Login at: /portal/{schema_name}/")
    print("   Use superuser: admin / admin123 (change password later).")

if __name__ == '__main__':
    main()
