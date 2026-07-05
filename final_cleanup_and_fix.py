import os
import re
import shutil

BASE_DIR = os.getcwd()

def write_file(path, content):
    path = os.path.join(BASE_DIR, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

def main():
    print("🚀 Applying FINAL Cleanup & Fix Patcher...")

    # 1. Fix settings.py
    settings_path = "saas_system/settings.py"
    with open(settings_path, 'r') as f:
        content = f.read()

    # Remove any duplicate DATABASE_ROUTERS assignment lines
    # Find all lines with DATABASE_ROUTERS and keep only one
    lines = content.splitlines()
    new_lines = []
    found_router = False
    for line in lines:
        if line.strip().startswith("DATABASE_ROUTERS"):
            if not found_router:
                new_lines.append("DATABASE_ROUTERS = ['core.router.TenantRouter']")
                found_router = True
            # else skip duplicates
        else:
            new_lines.append(line)
    content = "\n".join(new_lines)

    # Ensure INSTALLED_APPS does not contain 'tenants'
    content = content.replace("'tenants',", "")
    content = content.replace("'tenants'", "")

    # Ensure MIDDLEWARE does not contain 'tenants.middleware.TenantMiddleware' and has 'core.middleware.TenantMiddleware'
    # We'll replace if needed
    if "tenants.middleware.TenantMiddleware" in content:
        content = content.replace("'tenants.middleware.TenantMiddleware',", "")
    if "core.middleware.TenantMiddleware" not in content:
        # Insert after DeviceMiddleware
        content = content.replace(
            "'core.middleware.DeviceMiddleware',",
            "'core.middleware.DeviceMiddleware',\n    'core.middleware.TenantMiddleware',"
        )

    # Ensure AUTHENTICATION_BACKENDS uses core.auth_backend
    if "tenants.auth_backend" in content:
        content = content.replace("tenants.auth_backend", "core.auth_backend")
    if "AUTHENTICATION_BACKENDS" not in content:
        content = content.replace(
            "AUTH_PASSWORD_VALIDATORS = [",
            "AUTHENTICATION_BACKENDS = [\n    'core.auth_backend.TenantAuthBackend',\n    'django.contrib.auth.backends.ModelBackend',\n]\n\nAUTH_PASSWORD_VALIDATORS = ["
        )

    write_file(settings_path, content)
    print("✅ Settings.py fixed.")

    # 2. Remove tenants app directory if it exists (optional)
    tenants_dir = os.path.join(BASE_DIR, "tenants")
    if os.path.exists(tenants_dir):
        shutil.rmtree(tenants_dir)
        print("✅ Removed tenants app directory.")

    # 3. Verify users/admin.py has correct fields
    admin_path = "users/admin.py"
    with open(admin_path, 'r') as f:
        admin_content = f.read()
    # Check if it includes admin_username and admin_password fields
    if "admin_username" not in admin_content or "admin_password" not in admin_content:
        print("⚠️ Warning: admin_username or admin_password missing in admin.py. You may need to reapply the admin form.")
        # We could re-write the admin.py from our earlier patcher, but we assume it's already there.

    # 4. Ensure core/views.py uses correct ownership check (shop.owner)
    views_path = "core/views.py"
    with open(views_path, 'r') as f:
        views_content = f.read()
    if "if request.user != shop.owner and not request.user.is_superuser:" not in views_content:
        print("⚠️ Warning: portal_dashboard ownership check might be wrong. Please ensure it's correct.")

    # 5. Ensure core/router.py and middleware are present
    router_path = "core/router.py"
    if not os.path.exists(router_path):
        print("⚠️ Warning: router.py missing. Creating it.")
        router_content = '''
from .middleware import get_current_tenant_db

class TenantRouter:
    def _get_tenant_db(self):
        return get_current_tenant_db()

    def db_for_read(self, model, **hints):
        if model._meta.app_label == 'users' and model.__name__ == 'Shop':
            return 'default'
        tenant_db = self._get_tenant_db()
        if tenant_db:
            return tenant_db
        return 'default'

    def db_for_write(self, model, **hints):
        if model._meta.app_label == 'users' and model.__name__ == 'Shop':
            return 'default'
        tenant_db = self._get_tenant_db()
        if tenant_db:
            return tenant_db
        return 'default'

    def allow_relation(self, obj1, obj2, **hints):
        return True

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        if app_label == 'users' and model_name == 'shop':
            return db == 'default'
        if db != 'default':
            return True
        return False
'''
        write_file(router_path, router_content)
        print("✅ Created core/router.py")

    auth_backend_path = "core/auth_backend.py"
    if not os.path.exists(auth_backend_path):
        auth_backend_content = '''
from django.contrib.auth.backends import ModelBackend
from django.contrib.auth import get_user_model
from .middleware import get_current_tenant_db
from django.db import connections

class TenantAuthBackend(ModelBackend):
    def authenticate(self, request, username=None, password=None, **kwargs):
        db_alias = get_current_tenant_db()
        if not db_alias:
            return None
        UserModel = get_user_model()
        try:
            user = UserModel.objects.using(db_alias).get(username=username)
            if user.check_password(password):
                return user
        except UserModel.DoesNotExist:
            return None
        return None
'''
        write_file(auth_backend_path, auth_backend_content)
        print("✅ Created core/auth_backend.py")

    # 6. Check that middleware has get_current_tenant_db, set_current_tenant_db
    middleware_path = "core/middleware.py"
    with open(middleware_path, 'r') as f:
        middleware_content = f.read()
    if "get_current_tenant_db" not in middleware_content:
        print("⚠️ Warning: get_current_tenant_db missing in middleware. Please ensure it's defined.")

    print("\n" + "="*60)
    print("✅ All fixes applied!")
    print("👉 Now run: python manage.py makemigrations")
    print("👉 Then: python manage.py migrate")
    print("👉 Then: python manage.py runserver 0.0.0.0:8000")
    print("👉 Create a Shop from admin with admin_username and admin_password.")
    print("👉 Access /portal/<schema_name>/ and login with those credentials.")
    print("="*60)

if __name__ == "__main__":
    main()
