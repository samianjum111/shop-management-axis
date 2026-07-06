#!/usr/bin/env python3
import re
import os

SETTINGS_PATH = 'saas_system/settings.py'
PROCFILE_PATH = 'Procfile'

# 1. Update settings.py
with open(SETTINGS_PATH, 'r') as f:
    content = f.read()

# Replace the database engine with standard PostgreSQL
content = re.sub(
    r"'ENGINE': 'django_tenants\.postgresql_backend'",
    "'ENGINE': 'django.db.backends.postgresql'",
    content
)

# Remove the DATABASE_ROUTERS line (if present)
content = re.sub(
    r"DATABASE_ROUTERS\s*=\s*\[.*?\]",
    "",
    content,
    flags=re.DOTALL
)

# Comment out TenantMainMiddleware (avoid errors if not used)
content = re.sub(
    r"'django_tenants\.middleware\.main\.TenantMainMiddleware',  # must be first",
    "# 'django_tenants.middleware.main.TenantMainMiddleware',  # disabled for single-tenant",
    content
)

# Remove the tenant model setting if it exists (optional)
content = re.sub(
    r"TENANT_MODEL\s*=\s*[\"'].*?[\"']",
    "# TENANT_MODEL = 'tenants.Tenant'  # disabled",
    content
)

with open(SETTINGS_PATH, 'w') as f:
    f.write(content)

print("✅ Updated settings.py for single-tenant mode.")

# 2. Update Procfile
with open(PROCFILE_PATH, 'w') as f:
    f.write("web: python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn saas_system.wsgi\n")
print("✅ Procfile updated to use plain migrate.")

# 3. Optional: Remove the problematic 0003 migration if it exists (to avoid pending migration)
migration_file = 'tenants/migrations/0003_remove_tenant_db_host_remove_tenant_db_name_and_more.py'
if os.path.exists(migration_file):
    os.remove(migration_file)
    print(f"✅ Deleted {migration_file}")

print("\n🎉 All changes applied. Now commit and push:")
print("    git add .")
print("    git commit -m 'Switch to single-tenant mode to fix migration errors'")
print("    git push origin main")
