#!/usr/bin/env python3
import os
import subprocess
import sys

def run_cmd(cmd):
    print(f"▶ {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Error: {result.stderr}")
        return False
    print(f"✅ {result.stdout.strip() if result.stdout else 'OK'}")
    return True

def main():
    print("🔧 Fixing Tenant Migration Conflict")
    print("=" * 50)
    
    # Delete bad migration
    bad_migration = "tenants/migrations/0003_add_owner_field.py"
    if os.path.exists(bad_migration):
        os.remove(bad_migration)
        print(f"✅ Deleted: {bad_migration}")
    
    # Create clean migration
    if not run_cmd("python3 manage.py makemigrations tenants --name add_owner_simple"):
        print("❌ Failed to create migration")
        return
    
    # Show the migration
    run_cmd("ls -la tenants/migrations/")
    
    # Ask to push
    response = input("\n📦 Push changes to GitHub? (y/n): ").strip().lower()
    if response == 'y':
        run_cmd("git add .")
        run_cmd('git commit -m "Fix: Clean migration for owner field"')
        run_cmd("git push origin main")
    
    print("\n✅ Done! Railway will deploy automatically.")
    print("📌 After deployment, run on Railway Console:")
    print("   python3 manage.py migrate tenants")

if __name__ == "__main__":
    main()
