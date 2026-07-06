#!/usr/bin/env python3
import os
import re
import shutil

# 1. Revert tenants/models.py: change schema_name max_length back to 100
MODEL_PATH = 'tenants/models.py'
with open(MODEL_PATH, 'r') as f:
    content = f.read()
# Replace max_length=63 with max_length=100
content = re.sub(r"schema_name = models\.CharField\(max_length=63, unique=True\)",
                 'schema_name = models.CharField(max_length=100, unique=True)',
                 content)
with open(MODEL_PATH, 'w') as f:
    f.write(content)
print("✅ Reverted schema_name max_length to 100 in tenants/models.py")

# 2. Delete the problematic migration file (0003)
migration_file = 'tenants/migrations/0003_remove_tenant_db_host_remove_tenant_db_name_and_more.py'
if os.path.exists(migration_file):
    os.remove(migration_file)
    print(f"✅ Deleted {migration_file}")
else:
    print(f"⚠️ {migration_file} not found, skipping")

# Also remove any __pycache__ if present (optional)
pycache = 'tenants/migrations/__pycache__'
if os.path.exists(pycache):
    shutil.rmtree(pycache)
    print("✅ Removed __pycache__")

# 3. Update Procfile – use plain migrate, no migrate_schemas
PROCFILE_PATH = 'Procfile'
new_procfile = """web: python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn saas_system.wsgi
"""
with open(PROCFILE_PATH, 'w') as f:
    f.write(new_procfile)
print("✅ Procfile updated – uses migrate only, no migrate_schemas")

# 4. (Optional) Clean up any orphaned .pyc files
os.system("find . -name '*.pyc' -delete")

print("\n🎉 All changes applied. Now commit and push:")
print("    git add .")
print("    git commit -m 'Revert tenant migration and use plain migrate'")
print("    git push origin main")
