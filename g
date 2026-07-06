#!/usr/bin/env python3
import os
import re

SETTINGS_PATH = 'saas_system/settings.py'

# 1. Remove 'tenants' from TENANT_APPS and keep only in SHARED_APPS
with open(SETTINGS_PATH, 'r') as f:
    content = f.read()

# Remove 'tenants' from TENANT_APPS if present
content = re.sub(r"TENANT_APPS\s*=\s*\(\s*'core',\s*'chakki',\s*'expenses',\s*'tenants',\s*\)", 
                 "TENANT_APPS = (\n    'core',\n    'chakki',\n    'expenses',\n)", 
                 content)

# Make sure SHARED_APPS has 'tenants'
if "'tenants'" not in content or '"tenants"' not in content:
    content = content.replace("'tenants',         # this app holds the Tenant model", 
                              "'tenants',         # this app holds the Tenant model")

with open(SETTINGS_PATH, 'w') as f:
    f.write(content)

print("✅ Removed 'tenants' from TENANT_APPS (only in SHARED_APPS now)")

# 2. Delete the problematic migration file if it exists
migration_file = 'tenants/migrations/0003_remove_tenant_db_host_remove_tenant_db_name_and_more.py'
if os.path.exists(migration_file):
    os.remove(migration_file)
    print(f"✅ Deleted {migration_file}")

# 3. Update Procfile – use plain migrate
PROCFILE_PATH = 'Procfile'
with open(PROCFILE_PATH, 'w') as f:
    f.write("web: python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn saas_system.wsgi\n")
print("✅ Procfile updated – uses migrate only")

print("\n🎉 All done! Now commit and push:")
print("    git add .")
print("    git commit -m 'Remove tenants from TENANT_APPS, use plain migrate'")
print("    git push origin main")
