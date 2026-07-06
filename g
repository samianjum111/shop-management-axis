#!/usr/bin/env python3
import os
import re

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 1. requirements.txt – add dj-database-url
req_path = os.path.join(BASE_DIR, 'requirements.txt')
with open(req_path, 'r') as f:
    reqs = f.read()
if 'dj-database-url' not in reqs:
    with open(req_path, 'a') as f:
        f.write('\ndj-database-url==2.0.0\n')

# 2. settings.py – modify DATABASES to use DATABASE_URL
settings_path = os.path.join(BASE_DIR, 'saas_system', 'settings.py')
with open(settings_path, 'r') as f:
    content = f.read()

# Add import for dj_database_url if not present
if 'import dj_database_url' not in content:
    # Insert after load_dotenv
    content = content.replace('load_dotenv()', 'load_dotenv()\nimport dj_database_url\n')

# Replace DATABASES dictionary with dynamic config
# Find the DATABASES block
db_pattern = r"DATABASES\s*=\s*\{[^}]+\}"
if re.search(db_pattern, content):
    new_db = '''DATABASES = {
    'default': dj_database_url.config(default=os.getenv('DATABASE_URL'), conn_max_age=600)
}'''
    content = re.sub(db_pattern, new_db, content)
else:
    # If not found, append at the end (safety)
    content += '\n\nDATABASES = {\n    "default": dj_database_url.config(default=os.getenv("DATABASE_URL"), conn_max_age=600)\n}\n'

# Also ensure ALLOWED_HOSTS is set to allow '*'
if 'ALLOWED_HOSTS' in content:
    # Replace ALLOWED_HOSTS line
    content = re.sub(r'ALLOWED_HOSTS\s*=\s*\[[^\]]*\]', 'ALLOWED_HOSTS = ["*"]', content)
else:
    content += '\nALLOWED_HOSTS = ["*"]\n'

with open(settings_path, 'w') as f:
    f.write(content)

# 3. Single-tenant patch (if not already applied)
# We'll just reapply core/router.py, middleware, context_processors (idempotent)

router_code = '''class TenantRouter:
    def db_for_read(self, model, **hints):
        return 'default'
    def db_for_write(self, model, **hints):
        return 'default'
    def allow_relation(self, obj1, obj2, **hints):
        return True
    def allow_migrate(self, db, app_label, model_name=None, **hints):
        return db == 'default'
'''
with open(os.path.join(BASE_DIR, 'core', 'router.py'), 'w') as f:
    f.write(router_code)

middleware_code = '''from tenants.models import Tenant

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

class TenantMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
    def __call__(self, request):
        from tenants.models import Tenant
        dummy_tenant = Tenant(name='My Shop', schema_name='default', db_name='default')
        request.tenant = dummy_tenant
        response = self.get_response(request)
        return response
'''
with open(os.path.join(BASE_DIR, 'core', 'middleware.py'), 'w') as f:
    f.write(middleware_code)

context_code = '''def tenant_processor(request):
    from tenants.models import Tenant
    dummy_tenant = Tenant(name='My Shop', schema_name='default', db_name='default')
    return {'tenant': getattr(request, 'tenant', dummy_tenant)}

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
with open(os.path.join(BASE_DIR, 'core', 'context_processors.py'), 'w') as f:
    f.write(context_code)

# 4. Ensure Procfile and runtime.txt exist (already created)
procfile = "web: gunicorn saas_system.wsgi"
with open(os.path.join(BASE_DIR, 'Procfile'), 'w') as f:
    f.write(procfile)

runtime = "python-3.12"
with open(os.path.join(BASE_DIR, 'runtime.txt'), 'w') as f:
    f.write(runtime)

print("✅ All fixes applied! Now commit and push:")
print("git add . && git commit -m 'Fix database URL and single-tenant' && git push origin main")
