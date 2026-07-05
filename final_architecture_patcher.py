import os
import shutil
import re
import sys

BASE_DIR = os.getcwd()

def write_file(path, content):
    path = os.path.join(BASE_DIR, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

def main():
    print("🚀 Refactoring to clean multi‑database architecture...")

    # 1. Create tenants app with models/admin
    tenants_dir = os.path.join(BASE_DIR, "tenants")
    os.makedirs(tenants_dir, exist_ok=True)
    with open(os.path.join(tenants_dir, '__init__.py'), 'w') as f:
        pass

    write_file("tenants/models.py", '''
from django.db import models
from django.contrib.auth.models import User

class Tenant(models.Model):
    name = models.CharField(max_length=100)
    schema_name = models.CharField(max_length=100, unique=True)
    db_name = models.CharField(max_length=100, unique=True)
    db_user = models.CharField(max_length=100, blank=True)
    db_password = models.CharField(max_length=100, blank=True)
    db_host = models.CharField(max_length=100, default='localhost')
    db_port = models.CharField(max_length=10, default='5432')
    owner = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name
''')

    write_file("tenants/admin.py", '''
from django.contrib import admin
from django import forms
from django.conf import settings
from django.core.management import call_command
from .models import Tenant
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

class TenantAdminForm(forms.ModelForm):
    admin_username = forms.CharField(max_length=150, required=True, help_text="Admin username for this shop (tenant DB)")
    admin_password = forms.CharField(widget=forms.PasswordInput, required=True, help_text="Admin password for this shop (tenant DB)")

    class Meta:
        model = Tenant
        fields = '__all__'
        exclude = ['db_user', 'db_password']  # auto‑generated

    def save(self, commit=True):
        tenant = super().save(commit=False)
        if not tenant.pk:
            import secrets
            tenant.db_name = f"shop_{secrets.token_hex(4)}"
            tenant.db_user = f"user_{secrets.token_hex(4)}"
            tenant.db_password = secrets.token_urlsafe(16)

            # Create database
            conn = psycopg2.connect(
                dbname='postgres',
                user=settings.DATABASES['default']['USER'],
                password=settings.DATABASES['default']['PASSWORD'],
                host=settings.DATABASES['default']['HOST'],
                port=settings.DATABASES['default']['PORT']
            )
            conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
            cur = conn.cursor()
            cur.execute(f"CREATE DATABASE {tenant.db_name} OWNER {settings.DATABASES['default']['USER']};")
            cur.close()
            conn.close()

            # Add DB connection
            default_db = settings.DATABASES['default'].copy()
            default_db['NAME'] = tenant.db_name
            settings.DATABASES[tenant.db_name] = default_db

            # Run migrations on new DB (all apps except 'tenants')
            call_command('migrate', database=tenant.db_name, verbosity=2, interactive=False)

            # Create admin user in tenant DB
            admin_username = self.cleaned_data.get('admin_username')
            admin_password = self.cleaned_data.get('admin_password')
            from django.contrib.auth import get_user_model
            User = get_user_model()
            User.objects.using(tenant.db_name).create_superuser(
                username=admin_username,
                password=admin_password,
                email=''
            )
        if commit:
            tenant.save()
        return tenant

@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    form = TenantAdminForm
    list_display = ('name', 'schema_name', 'db_name', 'owner', 'created_at')
    search_fields = ('name', 'schema_name', 'db_name')
    readonly_fields = ('db_name', 'db_user', 'db_password')
''')

    write_file("tenants/apps.py", '''
from django.apps import AppConfig

class TenantsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'tenants'
''')

    # 2. Remove db_name, db_user, db_password from Shop model (users/models.py)
    users_models_path = "users/models.py"
    with open(users_models_path, 'r') as f:
        content = f.read()
    # Remove the db fields and update the save method to only handle schema_name
    # We'll replace the whole Shop model with a simpler version.
    new_shop_model = '''
from django.contrib.auth.models import User
from django.db import models
from django.core.validators import RegexValidator

class Shop(models.Model):
    CATEGORY_CHOICES = [
        ('chakki', 'Chakki (Flour Mill)'),
        # add more later
    ]
    owner = models.OneToOneField(User, on_delete=models.CASCADE, null=True, blank=True)
    name = models.CharField(max_length=100)
    schema_name = models.CharField(
        max_length=100,
        unique=True,
        blank=True,
        help_text="Portal URL slug, e.g., 'hafeezchakki' (only letters, numbers, underscore, hyphen)",
        validators=[RegexValidator(r'^[a-zA-Z0-9_-]+$', 'Only letters, numbers, underscore and hyphen allowed.')]
    )
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='chakki')
    phone = models.CharField(max_length=20, blank=True)
    address = models.TextField(blank=True)
    total_earnings = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if not self.schema_name:
            from django.utils.text import slugify
            self.schema_name = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name
'''
    # Find the class definition and replace
    import re
    pattern = r'(class Shop\(models\.Model\):.*?)(?=\n\n|$)'
    content = re.sub(pattern, new_shop_model, content, flags=re.DOTALL)
    write_file(users_models_path, content)
    print("✅ Shop model updated (db fields removed).")

    # 3. Update users/admin.py to remove tenant credentials (they are now in TenantAdmin)
    # We'll keep ShopAdmin for managing shop data (but we might not need it anymore)
    # For simplicity, we keep it but remove the credentials fields.
    users_admin_path = "users/admin.py"
    with open(users_admin_path, 'r') as f:
        admin_content = f.read()
    # Remove the ShopAdminForm and replace with simple admin
    new_admin = '''
from django.contrib import admin
from django.utils.html import format_html
from .models import Shop

@admin.register(Shop)
class ShopAdmin(admin.ModelAdmin):
    list_display = ('name', 'schema_name', 'category', 'phone', 'portal_links')
    search_fields = ('name', 'schema_name')
    readonly_fields = ('owner',)

    def portal_links(self, obj):
        if obj and obj.schema_name:
            desktop_url = f'/portal/{obj.schema_name}/'
            mobile_url = f'/portal/{obj.schema_name}/?mobile=1'
            return format_html(
                '<a href="{}" target="_blank" class="button">🖥️ Desktop Portal</a>&nbsp;&nbsp;'
                '<a href="{}" target="_blank" class="button">📱 Mobile Portal</a>',
                desktop_url, mobile_url
            )
        return "-"
    portal_links.short_description = "Portal Access"
'''
    write_file(users_admin_path, new_admin)
    print("✅ users/admin.py updated.")

    # 4. Update core/middleware.py to use Tenant model instead of Shop for metadata
    middleware_path = "core/middleware.py"
    with open(middleware_path, 'r') as f:
        mid_content = f.read()
    # Replace imports and logic
    new_middleware = '''
from django.shortcuts import redirect
from django.urls import reverse
from tenants.models import Tenant
import threading

_thread_local = threading.local()

def get_current_tenant_db():
    return getattr(_thread_local, 'current_db', None)

def set_current_tenant_db(db_alias):
    _thread_local.current_db = db_alias

class DeviceMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
    def __call__(self, request):
        request.mobile = False
        user_agent = request.META.get('HTTP_USER_AGENT', '')
        if any(x in user_agent for x in ['Mobile', 'Android', 'iPhone']):
            request.mobile = True
        return self.get_response(request)

class TenantMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        set_current_tenant_db(None)
        request.tenant = None
        if request.path.startswith('/portal/'):
            parts = request.path.split('/')
            if len(parts) >= 3:
                schema = parts[2]
                if schema:
                    try:
                        tenant = Tenant.objects.get(schema_name=schema)
                        if tenant.db_name:
                            set_current_tenant_db(tenant.db_name)
                            request.tenant = tenant
                    except Tenant.DoesNotExist:
                        pass
        response = self.get_response(request)
        set_current_tenant_db(None)
        return response
'''
    write_file(middleware_path, new_middleware)
    print("✅ core/middleware.py updated.")

    # 5. Update core/router.py to use Tenant model and restrict only tenants app to default
    router_path = "core/router.py"
    router_content = '''
from .middleware import get_current_tenant_db

class TenantRouter:
    def _get_tenant_db(self):
        return get_current_tenant_db()

    def db_for_read(self, model, **hints):
        if model._meta.app_label == 'tenants':
            return 'default'
        tenant_db = self._get_tenant_db()
        if tenant_db:
            return tenant_db
        return 'default'

    def db_for_write(self, model, **hints):
        if model._meta.app_label == 'tenants':
            return 'default'
        tenant_db = self._get_tenant_db()
        if tenant_db:
            return tenant_db
        return 'default'

    def allow_relation(self, obj1, obj2, **hints):
        return True

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        # Only tenants app on default, everything else on tenant DBs
        if app_label == 'tenants':
            return db == 'default'
        if db != 'default':
            return True
        # For default, we only migrate tenants app and built‑in apps? We'll handle it.
        # We want admin, auth, contenttypes, sessions on default as well.
        if app_label in ['admin', 'auth', 'contenttypes', 'sessions']:
            return db == 'default'
        return False
'''
    write_file(router_path, router_content)
    print("✅ core/router.py updated.")

    # 6. Update core/views.py to use Tenant instead of Shop for ownership
    views_path = "core/views.py"
    with open(views_path, 'r') as f:
        views_content = f.read()
    # Replace portal_dashboard
    import re
    pattern = r'(@login_required\s+def portal_dashboard\(request, schema_name\):.*?)(?=\ndef |\Z)'
    replacement = '''
@login_required
def portal_dashboard(request, schema_name):
    from tenants.models import Tenant
    tenant = get_object_or_404(Tenant, schema_name=schema_name)
    if request.user != tenant.owner and not request.user.is_superuser:
        raise Http404("You do not have access to this shop.")
    request.tenant = tenant
    # Set request.shop for templates? We'll use tenant instead.
    # We'll also need to fetch the shop from tenant DB? Actually we can just pass tenant.
    # For backward compatibility, we'll set request.shop to a Shop object from tenant DB? Not necessary.
    # Just use tenant.
    # Import chakki dashboard and render
    from chakki.views import dashboard as chakki_dashboard
    return chakki_dashboard(request)
'''
    new_views_content = re.sub(pattern, replacement, views_content, flags=re.DOTALL)
    write_file(views_path, new_views_content)
    print("✅ core/views.py updated.")

    # 7. Update core/context_processors.py to use Tenant
    cp_path = "core/context_processors.py"
    with open(cp_path, 'r') as f:
        cp_content = f.read()
    # Replace tenant_shop with tenant
    cp_content = cp_content.replace("tenant_shop", "tenant_processor")
    cp_content = cp_content.replace("'tenant_shop'", "'tenant'")
    # Also update the function to return tenant
    cp_content = cp_content.replace("shop = getattr(request, 'tenant_shop', None)", "tenant = getattr(request, 'tenant', None)")
    cp_content = cp_content.replace("{'tenant_shop': shop}", "{'tenant': tenant}")
    write_file(cp_path, cp_content)
    print("✅ core/context_processors.py updated.")

    # 8. Update login template to show tenant.name instead of tenant_shop.name
    login_template = "templates/desktop/login.html"
    if os.path.exists(login_template):
        with open(login_template, 'r') as f:
            login_content = f.read()
        login_content = login_content.replace("tenant_shop", "tenant")
        write_file(login_template, login_content)
        print("✅ login.html updated.")

    # 9. Update the admin form for Tenant to handle shop creation? Already done in tenants/admin.py

    # 10. Remove old migrations for tenants? We'll create new migrations.
    # We'll delete the tenants app if exists (it should be new)
    # Ensure we add 'tenants' to INSTALLED_APPS and remove any old entries
    settings_path = "saas_system/settings.py"
    with open(settings_path, 'r') as f:
        settings_content = f.read()
    # Add 'tenants' to INSTALLED_APPS
    if "'tenants'" not in settings_content:
        settings_content = settings_content.replace(
            "INSTALLED_APPS = [",
            "INSTALLED_APPS = [\n    'tenants',"
        )
    # Remove any duplicates of 'tenants' if already present (we'll just add once)
    # Also ensure MIDDLEWARE has core.middleware.TenantMiddleware
    if "core.middleware.TenantMiddleware" not in settings_content:
        settings_content = settings_content.replace(
            "'core.middleware.DeviceMiddleware',",
            "'core.middleware.DeviceMiddleware',\n    'core.middleware.TenantMiddleware',"
        )
    # Ensure AUTHENTICATION_BACKENDS has core.auth_backend.TenantAuthBackend
    if "core.auth_backend.TenantAuthBackend" not in settings_content:
        settings_content = settings_content.replace(
            "AUTH_PASSWORD_VALIDATORS = [",
            "AUTHENTICATION_BACKENDS = [\n    'core.auth_backend.TenantAuthBackend',\n    'django.contrib.auth.backends.ModelBackend',\n]\n\nAUTH_PASSWORD_VALIDATORS = ["
        )
    # Ensure DATABASE_ROUTERS = ['core.router.TenantRouter']
    if "DATABASE_ROUTERS" not in settings_content:
        settings_content += "\n\nDATABASE_ROUTERS = ['core.router.TenantRouter']"
    write_file(settings_path, settings_content)
    print("✅ settings.py updated.")

    # 11. Remove the old Shop migrations that added db_name fields? We'll just let new migrations handle.
    # We need to delete the old migration file that added db_name? It's already applied, but we can create a new migration to remove them.
    # Instead of deleting, we'll let Django generate a migration to remove them automatically.
    # We'll just run makemigrations after.

    print("\n" + "="*60)
    print("✅ Architecture upgrade complete!")
    print("👉 Next steps:")
    print("1. Run: python manage.py makemigrations tenants users")
    print("2. Then: python manage.py migrate")
    print("3. Then: python manage.py runserver 0.0.0.0:8000")
    print("4. In admin, create a Tenant (instead of Shop). Enter admin_username/password.")
    print("5. The system will create a tenant database and migrate all tables (except tenants).")
    print("6. Access portal: /portal/<schema_name>/ and login with admin_username/password.")
    print("="*60)

if __name__ == "__main__":
    main()
