#!/usr/bin/env python3
import os
import re
import shutil

# 1. Revert schema_name max_length to 100
MODEL_PATH = 'tenants/models.py'
with open(MODEL_PATH, 'r') as f:
    content = f.read()
content = re.sub(r"schema_name = models\.CharField\(max_length=63, unique=True\)",
                 'schema_name = models.CharField(max_length=100, unique=True)',
                 content)
with open(MODEL_PATH, 'w') as f:
    f.write(content)
print("✅ Reverted schema_name to max_length=100")

# 2. Delete the 0003 migration if it exists
migration_file = 'tenants/migrations/0003_remove_tenant_db_host_remove_tenant_db_name_and_more.py'
if os.path.exists(migration_file):
    os.remove(migration_file)
    print(f"✅ Deleted {migration_file}")

# Also delete __pycache__ in tenants/migrations
pycache = 'tenants/migrations/__pycache__'
if os.path.exists(pycache):
    shutil.rmtree(pycache)
    print("✅ Removed __pycache__")

# 3. Update Procfile – only migrate, no migrate_schemas
with open('Procfile', 'w') as f:
    f.write("web: python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn saas_system.wsgi\n")
print("✅ Procfile updated – now uses only migrate")

print("\n🎉 All clean. Now commit and push:")
print("    git add .")
print("    git commit -m 'Final fix: revert tenant model, remove bad migration, use plain migrate'")
print("    git push origin main")
