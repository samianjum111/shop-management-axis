#!/usr/bin/env python3
import os
import re
import shutil

# 1. Rewrite tenants/models.py to a simple model (no django-tenants)
MODEL_PATH = 'tenants/models.py'
new_model = '''from django.db import models

class Tenant(models.Model):
    name = models.CharField(max_length=100)
    schema_name = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    category = models.CharField(max_length=20, default='chakki')

    def __str__(self):
        return self.name
'''
with open(MODEL_PATH, 'w') as f:
    f.write(new_model)
print("✅ Replaced tenants/models.py with simple Tenant model")

# 2. Remove Domain model and other django-tenants dependencies from admin.py
ADMIN_PATH = 'tenants/admin.py'
new_admin = '''from django.contrib import admin
from .models import Tenant

@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    list_display = ('name', 'schema_name', 'category', 'created_at')
    readonly_fields = ('created_at',)
'''
with open(ADMIN_PATH, 'w') as f:
    f.write(new_admin)
print("✅ Updated tenants/admin.py")

# 3. Update settings.py: remove django_tenants, fix DB engine, remove middleware/router
SETTINGS_PATH = 'saas_system/settings.py'
with open(SETTINGS_PATH, 'r') as f:
    content = f.read()

# Remove django_tenants from SHARED_APPS and keep only tenants in INSTALLED_APPS
content = re.sub(
    r"SHARED_APPS\s*=\s*\([^)]*\)",
    "SHARED_APPS = (\n    'django.contrib.admin',\n    'django.contrib.auth',\n    'django.contrib.contenttypes',\n    'django.contrib.sessions',\n    'django.contrib.messages',\n    'django.contrib.staticfiles',\n    'tenants',         # simple tenant model\n)",
    content,
    flags=re.DOTALL
)

# Remove TENANT_APPS and INSTALLED_APPS overrides - we'll define INSTALLED_APPS directly
# Replace the INSTALLED_APPS line with a simple list
content = re.sub(
    r"INSTALLED_APPS\s*=\s*[^\n]*",
    "INSTALLED_APPS = [\n    'django.contrib.admin',\n    'django.contrib.auth',\n    'django.contrib.contenttypes',\n    'django.contrib.sessions',\n    'django.contrib.messages',\n    'django.contrib.staticfiles',\n    'tenants',\n    'core',\n    'chakki',\n    'expenses',\n]",
    content
)

# Remove TenantMainMiddleware from MIDDLEWARE
content = re.sub(
    r"'django_tenants\.middleware\.main\.TenantMainMiddleware',\s*# must be first",
    "# 'django_tenants.middleware.main.TenantMainMiddleware',  # removed",
    content
)

# Remove DATABASE_ROUTERS line
content = re.sub(
    r"DATABASE_ROUTERS\s*=\s*\[[^\]]*\]",
    "# DATABASE_ROUTERS = []  # removed",
    content
)

# Change database engine to standard PostgreSQL
content = re.sub(
    r"'ENGINE': 'django_tenants\.postgresql_backend'",
    "'ENGINE': 'django.db.backends.postgresql'",
    content
)

# Remove TENANT_MODEL line (if any)
content = re.sub(
    r"TENANT_MODEL\s*=\s*.*",
    "# TENANT_MODEL removed",
    content
)

# Also remove the middleware import if present
content = content.replace("'django_tenants.middleware.main.TenantMainMiddleware',", "")

with open(SETTINGS_PATH, 'w') as f:
    f.write(content)
print("✅ Updated settings.py")

# 4. Update core/views.py: remove Tenant dependency, use simple get_object_or_404 on our model
VIEWS_PATH = 'core/views.py'
with open(VIEWS_PATH, 'r') as f:
    v_content = f.read()

# Remove the import from tenants.models
v_content = re.sub(r"from tenants\.models import Tenant", "# from tenants.models import Tenant", v_content)
# In portal_login, replace get_object_or_404(Tenant, ...) with a dummy or use our model
v_content = re.sub(
    r"tenant = get_object_or_404\(Tenant, schema_name=schema_name\)",
    "tenant = Tenant.objects.filter(schema_name=schema_name).first()\n    if not tenant:\n        raise Http404(\"Tenant not found\")",
    v_content
)

with open(VIEWS_PATH, 'w') as f:
    f.write(v_content)
print("✅ Updated core/views.py")

# 5. Simplify core/middleware.py: remove tenant connection logic
MIDDLEWARE_PATH = 'core/middleware.py'
with open(MIDDLEWARE_PATH, 'r') as f:
    m_content = f.read()

# Replace TenantFromPathMiddleware to just set tenant from simple model
m_content = re.sub(
    r"class TenantFromPathMiddleware:.*?return response",
    '''class TenantFromPathMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path_info
        if path.startswith('/portal/'):
            parts = path.split('/')
            if len(parts) >= 3:
                schema_name = parts[2]
                from tenants.models import Tenant
                try:
                    tenant = Tenant.objects.get(schema_name=schema_name)
                    request.tenant = tenant
                except Tenant.DoesNotExist:
                    raise Http404("Tenant not found")
        else:
            request.tenant = None
        response = self.get_response(request)
        return response''',
    m_content,
    flags=re.DOTALL
)

with open(MIDDLEWARE_PATH, 'w') as f:
    f.write(m_content)
print("✅ Updated core/middleware.py")

# 6. Update Procfile
with open('Procfile', 'w') as f:
    f.write("web: python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn saas_system.wsgi\n")
print("✅ Procfile updated")

# 7. Delete any leftover problematic migration (just in case)
migration_file = 'tenants/migrations/0003_remove_tenant_db_host_remove_tenant_db_name_and_more.py'
if os.path.exists(migration_file):
    os.remove(migration_file)
    print(f"✅ Deleted {migration_file}")

# Also clear __pycache__ to avoid stale imports
for root, dirs, files in os.walk('tenants/migrations'):
    if '__pycache__' in dirs:
        shutil.rmtree(os.path.join(root, '__pycache__'))
print("✅ Removed __pycache__")

print("\n🎉 All changes applied. Now commit and push:")
print("    git add .")
print("    git commit -m 'Remove django-tenants, use simple tenant model, single-tenant mode'")
print("    git push origin main")
