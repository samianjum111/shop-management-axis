#!/usr/bin/env python3
import re
import os

SETTINGS_PATH = 'saas_system/settings.py'
PROCFILE_PATH = 'Procfile'

with open(SETTINGS_PATH, 'r') as f:
    content = f.read()

# 1. Ensure TENANT_MODEL is defined
if 'TENANT_MODEL' not in content or 'TENANT_MODEL' in content and content.find('TENANT_MODEL') != -1:
    # If it's commented out, uncomment or set it
    content = re.sub(r'#?\s*TENANT_MODEL\s*=\s*.*', "TENANT_MODEL = 'tenants.Tenant'", content)
else:
    # Add it after database settings
    content = content.replace("DATABASE_ROUTERS", "TENANT_MODEL = 'tenants.Tenant'\n\nDATABASE_ROUTERS")

# 2. Remove TenantMainMiddleware from MIDDLEWARE
content = re.sub(
    r"'django_tenants\.middleware\.main\.TenantMainMiddleware',\s*# must be first",
    "# 'django_tenants.middleware.main.TenantMainMiddleware',  # removed for single-tenant",
    content
)

# 3. Remove or empty DATABASE_ROUTERS (to avoid tenant routing)
content = re.sub(
    r"DATABASE_ROUTERS\s*=\s*\[[^\]]*\]",
    "DATABASE_ROUTERS = []  # disabled for single-tenant",
    content
)

# 4. Change database engine to standard PostgreSQL
content = re.sub(
    r"'ENGINE': 'django_tenants\.postgresql_backend'",
    "'ENGINE': 'django.db.backends.postgresql'",
    content
)

with open(SETTINGS_PATH, 'w') as f:
    f.write(content)

print("✅ Updated settings.py: TENANT_MODEL set, middleware/router disabled, engine changed.")

# 5. Update Procfile
with open(PROCFILE_PATH, 'w') as f:
    f.write("web: python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn saas_system.wsgi\n")
print("✅ Procfile updated to use plain migrate.")

# 6. Remove any conflicting migration (0003) if present
migration_file = 'tenants/migrations/0003_remove_tenant_db_host_remove_tenant_db_name_and_more.py'
if os.path.exists(migration_file):
    os.remove(migration_file)
    print(f"✅ Deleted {migration_file}")

print("\n🎉 All changes applied. Now commit and push:")
print("    git add .")
print("    git commit -m 'Fix TENANT_MODEL, disable multi-tenant, use standard DB'")
print("    git push origin main")
