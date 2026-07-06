#!/usr/bin/env python3
"""
Patcher to convert project to schema-based multi-tenancy using django-tenants.
Run this script once, then commit and push.
"""

import os
import re
import shutil
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

# ----------------------------------------------------------------------
# 1. settings.py - replace with django-tenants configuration
# ----------------------------------------------------------------------
settings_path = BASE_DIR / "saas_system" / "settings.py"
with open(settings_path, "r") as f:
    settings_content = f.read()

# We'll completely replace the file with new content.
# But we'll preserve environment variables and some user settings.
new_settings = '''import os
from pathlib import Path
from dotenv import load_dotenv
load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv('SECRET_KEY')
DEBUG = os.getenv('DEBUG', 'False') == 'True'
ALLOWED_HOSTS = ['*']

CSRF_TRUSTED_ORIGINS = [
    'https://shop-management-axis-production.up.railway.app',
    'https://*.railway.app',
]

# ---------- django-tenants settings ----------
SHARED_APPS = (
    'django_tenants',  # must be first
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'tenants',         # this app holds the Tenant model
)

TENANT_APPS = (
    'core',
    'chakki',
    'expenses',
)

INSTALLED_APPS = list(SHARED_APPS) + [app for app in TENANT_APPS if app not in SHARED_APPS]

MIDDLEWARE = [
    'django_tenants.middleware.main.TenantMainMiddleware',  # must be first
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'core.middleware.DeviceMiddleware',
    'core.middleware.TenantFromPathMiddleware',
]

ROOT_URLCONF = 'saas_system.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'core.context_processors.tenant_processor',
                'core.context_processors.chakki_counts',
            ],
        },
    },
]

WSGI_APPLICATION = 'saas_system.wsgi.application'

# Database – use django-tenants backend
DATABASES = {
    'default': {
        'ENGINE': 'django_tenants.postgresql_backend',
        'NAME': os.getenv('DB_NAME'),
        'USER': os.getenv('DB_USER'),
        'PASSWORD': os.getenv('DB_PASSWORD'),
        'HOST': os.getenv('DB_HOST'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}

DATABASE_ROUTERS = [
    'django_tenants.routers.TenantSyncRouter',
]

TENANT_MODEL = "tenants.Tenant"   # app.Model

# Authentication – use default backend
AUTHENTICATION_BACKENDS = [
    'django.contrib.auth.backends.ModelBackend',
]

# Password validation (unchanged)
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Karachi'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

LOGIN_URL = '/login/'
LOGIN_REDIRECT_URL = '/'
LOGOUT_REDIRECT_URL = '/login/'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True
'''

with open(settings_path, "w") as f:
    f.write(new_settings)
print("✅ settings.py updated with django-tenants configuration.")

# ----------------------------------------------------------------------
# 2. tenants/models.py
# ----------------------------------------------------------------------
tenants_models_path = BASE_DIR / "tenants" / "models.py"
tenants_models_content = '''from django.db import models
from django_tenants.models import TenantMixin, DomainMixin

class Tenant(TenantMixin):
    name = models.CharField(max_length=100)
    schema_name = models.CharField(max_length=63, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    category = models.CharField(max_length=20, default='chakki')

    auto_create_schema = True
    auto_drop_schema = False

    def __str__(self):
        return self.name

class Domain(DomainMixin):
    pass
'''
with open(tenants_models_path, "w") as f:
    f.write(tenants_models_content)
print("✅ tenants/models.py updated.")

# ----------------------------------------------------------------------
# 3. tenants/admin.py - with admin_username/password fields
# ----------------------------------------------------------------------
tenants_admin_path = BASE_DIR / "tenants" / "admin.py"
tenants_admin_content = '''from django.contrib import admin
from django import forms
from django_tenants.admin import TenantAdminMixin
from django_tenants.utils import schema_context
from django.contrib.auth import get_user_model
from .models import Tenant, Domain

User = get_user_model()

class TenantAdminForm(forms.ModelForm):
    admin_username = forms.CharField(max_length=150, required=True, label="Admin Username")
    admin_password = forms.CharField(widget=forms.PasswordInput, required=True, label="Admin Password")

    class Meta:
        model = Tenant
        fields = ('name', 'schema_name', 'category')

    def save(self, commit=True):
        tenant = super().save(commit=False)
        if not tenant.pk:
            tenant.save()
            with schema_context(tenant.schema_name):
                User.objects.create_superuser(
                    username=self.cleaned_data['admin_username'],
                    password=self.cleaned_data['admin_password'],
                    email=''
                )
        else:
            tenant.save()
        return tenant

@admin.register(Tenant)
class TenantAdmin(TenantAdminMixin, admin.ModelAdmin):
    form = TenantAdminForm
    list_display = ('name', 'schema_name', 'category', 'created_at')
    fields = ('name', 'schema_name', 'category', 'created_at')
    readonly_fields = ('created_at',)

@admin.register(Domain)
class DomainAdmin(admin.ModelAdmin):
    list_display = ('domain', 'tenant', 'is_primary')
'''
with open(tenants_admin_path, "w") as f:
    f.write(tenants_admin_content)
print("✅ tenants/admin.py updated with admin_username/password fields.")

# ----------------------------------------------------------------------
# 4. core/middleware.py - add TenantFromPathMiddleware, keep DeviceMiddleware
# ----------------------------------------------------------------------
middleware_path = BASE_DIR / "core" / "middleware.py"
# Read existing to preserve DeviceMiddleware
with open(middleware_path, "r") as f:
    mid_content = f.read()

# Check if TenantFromPathMiddleware already exists; if not, append
if "TenantFromPathMiddleware" not in mid_content:
    # Extract DeviceMiddleware class if present
    device_class = ""
    if "class DeviceMiddleware" in mid_content:
        # we'll just replace whole file with our version
        pass

new_middleware = '''from tenants.models import Tenant
from django_tenants.utils import get_tenant_model, get_public_schema_name, schema_context
from django.http import Http404

class DeviceMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
    def __call__(self, request):
        device = request.GET.get('device', '') or request.COOKIES.get('device', '')
        request.mobile = False
        if device.lower() == 'mobile':
            request.mobile = True
        elif device.lower() == 'desktop':
            request.mobile = False
        else:
            ua = request.META.get('HTTP_USER_AGENT', '')
            if any(x in ua for x in ['Mobile', 'Android', 'iPhone', 'iPad']):
                request.mobile = True
        return self.get_response(request)

class TenantFromPathMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path_info
        if path.startswith('/portal/'):
            parts = path.split('/')
            if len(parts) >= 3:
                schema_name = parts[2]
                try:
                    tenant = Tenant.objects.get(schema_name=schema_name)
                    request.tenant = tenant
                    from django.db import connection
                    connection.set_tenant(tenant)
                except Tenant.DoesNotExist:
                    raise Http404("Tenant not found")
        else:
            request.tenant = None
            from django.db import connection
            connection.set_schema_to_public()
        response = self.get_response(request)
        return response
'''
with open(middleware_path, "w") as f:
    f.write(new_middleware)
print("✅ core/middleware.py updated with TenantFromPathMiddleware.")

# ----------------------------------------------------------------------
# 5. core/context_processors.py - use request.tenant
# ----------------------------------------------------------------------
context_path = BASE_DIR / "core" / "context_processors.py"
context_content = '''def tenant_processor(request):
    return {'tenant': getattr(request, 'tenant', None)}

from chakki.models import ChakkiOrder
def chakki_counts(request):
    orders = ChakkiOrder.objects.all()
    pending_count = orders.filter(status='pending').count()
    ready_count = orders.filter(status='ready').count()
    partial_count = orders.filter(payment_status='partial').count()
    completed_count = orders.filter(status='completed').count()
    ready_orders = orders.filter(status='ready').order_by('-created_at')[:10]
    return {
        'pending_count': pending_count,
        'ready_count': ready_count,
        'partial_count': partial_count,
        'completed_count': completed_count,
        'ready_orders': ready_orders,
    }
'''
with open(context_path, "w") as f:
    f.write(context_content)
print("✅ core/context_processors.py updated.")

# ----------------------------------------------------------------------
# 6. core/views.py - simplify, rely on middleware
# ----------------------------------------------------------------------
views_path = BASE_DIR / "core" / "views.py"
views_content = '''from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.http import Http404
from tenants.models import Tenant

def portal_login(request, schema_name):
    tenant = get_object_or_404(Tenant, schema_name=schema_name)
    request.tenant = tenant
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)
        if user is not None:
            login(request, user)
            return redirect('portal_dashboard', schema_name=schema_name)
        else:
            return render(request, 'desktop/login.html', {'tenant': tenant, 'error': 'Invalid credentials'})
    return render(request, 'desktop/login.html', {'tenant': tenant})

def portal_logout(request, schema_name):
    logout(request)
    return redirect('portal_login', schema_name=schema_name)

def redirect_to_portal_login(request):
    next_url = request.GET.get('next', '')
    schema = None
    if next_url:
        parts = next_url.split('/')
        if len(parts) >= 3 and parts[1] == 'portal':
            schema = parts[2]
    if schema:
        from django.shortcuts import redirect
        return redirect(f'/portal/{schema}/?next={next_url}')
    else:
        from django.shortcuts import redirect
        return redirect('/admin/')

@login_required
def portal_dashboard(request, schema_name):
    tenant = get_object_or_404(Tenant, schema_name=schema_name)
    if request.user != tenant.owner and not request.user.is_superuser:
        raise Http404("Access denied")
    request.tenant = tenant
    from chakki.views import dashboard as chakki_dashboard
    return chakki_dashboard(request)
'''
with open(views_path, "w") as f:
    f.write(views_content)
print("✅ core/views.py updated.")

# ----------------------------------------------------------------------
# 7. Remove/comment out old files
# ----------------------------------------------------------------------
# core/router.py - we can delete or rename
router_path = BASE_DIR / "core" / "router.py"
if router_path.exists():
    router_path.unlink()
    print("🗑️ Removed core/router.py (not needed).")

# core/auth_backend.py - we can delete or rename
auth_backend_path = BASE_DIR / "core" / "auth_backend.py"
if auth_backend_path.exists():
    auth_backend_path.unlink()
    print("🗑️ Removed core/auth_backend.py (not needed).")

# ----------------------------------------------------------------------
# 8. requirements.txt - ensure django-tenants is present
# ----------------------------------------------------------------------
req_path = BASE_DIR / "requirements.txt"
with open(req_path, "r") as f:
    reqs = f.read()
if "django-tenants" not in reqs:
    with open(req_path, "a") as f:
        f.write("\ndjango-tenants==3.5.0\n")
    print("✅ Added django-tenants to requirements.txt.")

# ----------------------------------------------------------------------
# 9. Final message
# ----------------------------------------------------------------------
print("\n🎉 All files patched for schema-based multi-tenancy!")
print("\nNow run:")
print("  git add .")
print("  git commit -m 'Switch to schema-based multi-tenancy with django-tenants'")
print("  git push origin main")
print("\nAfter deployment, run migrations on Railway:")
print("  python manage.py migrate_schemas")
print("  python manage.py createsuperuser  # for public schema admin")
print("\nThen create tenants via admin panel – each will have its own schema and superuser.")
