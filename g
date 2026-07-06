#!/usr/bin/env python3
import os
import shutil

# Base directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 1. core/router.py
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

# 2. core/middleware.py
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
        # Create a dummy tenant (hardcoded)
        dummy_tenant = Tenant(
            name='My Shop',
            schema_name='default',
            db_name='default'
        )
        request.tenant = dummy_tenant
        response = self.get_response(request)
        return response
'''
with open(os.path.join(BASE_DIR, 'core', 'middleware.py'), 'w') as f:
    f.write(middleware_code)

# 3. core/context_processors.py
context_code = '''def tenant_processor(request):
    from tenants.models import Tenant
    # Return a dummy tenant (or fetch one if exists)
    dummy = Tenant(name='My Shop', schema_name='default', db_name='default')
    return {'tenant': getattr(request, 'tenant', dummy)}

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

# 4. settings.py – comment out DATABASE_ROUTERS line
settings_path = os.path.join(BASE_DIR, 'saas_system', 'settings.py')
with open(settings_path, 'r') as f:
    lines = f.readlines()
with open(settings_path, 'w') as f:
    for line in lines:
        if 'DATABASE_ROUTERS' in line and not line.strip().startswith('#'):
            f.write('# ' + line)
        else:
            f.write(line)

print("✅ Single-tenant patch applied successfully.")
print("📌 Now commit and push to GitHub, then deploy on Railway.")
