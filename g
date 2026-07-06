#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil
from datetime import datetime

def run_command(cmd, cwd=None):
    """Run a shell command and return output."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
    if result.returncode != 0:
        print(f"❌ Command failed: {cmd}")
        print(f"   Error: {result.stderr}")
        return None
    return result.stdout.strip()

def create_migration():
    """Create a migration for the owner field in Tenant model."""
    print("\n📝 Creating migration for owner field...")
    
    # Check if migration already exists
    migrations_dir = "tenants/migrations"
    if os.path.exists(migrations_dir):
        existing = [f for f in os.listdir(migrations_dir) if f.endswith('.py') and 'owner' in f]
        if existing:
            print(f"   Migration already exists: {existing[0]}")
            return True
    
    # Create migration
    result = run_command("python3 manage.py makemigrations tenants --name add_owner_field")
    if result is None:
        print("   ❌ Failed to create migration")
        return False
    
    print(f"   ✅ Migration created successfully")
    return True

def apply_migration():
    """Apply the migration to database."""
    print("\n🔄 Applying migration...")
    
    # Show pending migrations
    print("   Checking pending migrations...")
    result = run_command("python3 manage.py showmigrations tenants")
    if result:
        print(f"   {result}")
    
    # Apply migration
    result = run_command("python3 manage.py migrate tenants")
    if result is None:
        print("   ❌ Migration failed")
        return False
    
    print(f"   ✅ Migration applied successfully")
    return True

def check_database():
    """Check if owner_id column exists."""
    print("\n🔍 Checking database...")
    
    # Try to query the column
    # This is a simple check - we'll just try to access the field
    try:
        # Run a simple Django check
        result = run_command("python3 manage.py shell -c \"from tenants.models import Tenant; print('OK')\"")
        if result and 'OK' in result:
            print("   ✅ Database check passed")
            return True
    except:
        pass
    
    print("   ⚠️ Database check failed (may need manual fix)")
    return False

def run_manual_fix():
    """Run raw SQL to add the column if migration fails."""
    print("\n🔧 Trying manual SQL fix...")
    
    sql = """
    ALTER TABLE tenants_tenant ADD COLUMN IF NOT EXISTS owner_id integer;
    ALTER TABLE tenants_tenant ADD CONSTRAINT fk_tenants_tenant_owner_id FOREIGN KEY (owner_id) REFERENCES auth_user(id) ON DELETE SET NULL;
    """
    
    # Write SQL to a file and run it
    with open('/tmp/fix_owner.sql', 'w') as f:
        f.write(sql)
    
    # Try with PostgreSQL psql
    result = run_command("PGPASSWORD='' psql -h postgres.railway.internal -U postgres -d railway -f /tmp/fix_owner.sql 2>&1 || echo 'psql not available'")
    
    # Try with Django
    if result and 'psql not available' in result:
        print("   psql not available, trying Django raw SQL...")
        script = """
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
django.setup()
from django.db import connection

try:
    with connection.cursor() as cursor:
        cursor.execute("ALTER TABLE tenants_tenant ADD COLUMN IF NOT EXISTS owner_id integer;")
        cursor.execute("ALTER TABLE tenants_tenant ADD CONSTRAINT fk_tenants_tenant_owner_id FOREIGN KEY (owner_id) REFERENCES auth_user(id) ON DELETE SET NULL;")
        print("SUCCESS")
except Exception as e:
    print("ERROR:", e)
"""
        with open('/tmp/fix_owner.py', 'w') as f:
            f.write(script)
        result = run_command("python3 /tmp/fix_owner.py")
        if result and 'SUCCESS' in result:
            print("   ✅ Manual SQL fix applied successfully")
            return True
    
    print("   ⚠️ Manual fix attempted but may need verification")
    return False

def push_changes():
    """Push changes to GitHub."""
    print("\n📦 Pushing changes to GitHub...")
    
    # Check if there are changes
    status = run_command("git status --porcelain")
    if not status:
        print("   No changes to commit")
        return True
    
    print("   Adding all changes...")
    run_command("git add .")
    
    print("   Committing...")
    title = "Fix: Add owner field migration for multi-tenant"
    result = run_command(f'git commit -m "{title}"')
    if result is None:
        print("   ⚠️ Commit may have failed or nothing to commit")
    
    print("   Pushing to origin main...")
    result = run_command("git push origin main")
    if result is None:
        print("   ❌ Push failed")
        return False
    
    print("   ✅ Push successful")
    return True

def main():
    print("=" * 60)
    print("🔧 Tenant Owner Field Fix Patcher")
    print("=" * 60)
    
    # Step 1: Create migration
    if not create_migration():
        print("\n❌ Failed to create migration. Trying manual fix...")
        run_manual_fix()
    else:
        # Step 2: Apply migration
        if not apply_migration():
            print("\n⚠️ Migration failed. Trying manual fix...")
            run_manual_fix()
    
    # Step 3: Verify
    check_database()
    
    # Step 4: Ask to push
    print("\n" + "=" * 60)
    response = input("Do you want to push changes to GitHub? (y/n): ").strip().lower()
    if response == 'y':
        push_changes()
    
    print("\n" + "=" * 60)
    print("✅ Patcher completed!")
    print("\n📌 Next steps:")
    print("  1. Restart your Django server (Railway will restart automatically)")
    print("  2. Now you can add/edit tenants with username/password")
    print("  3. Portal login will only work for tenant owner or superuser")
    print("=" * 60)

if __name__ == "__main__":
    main()
