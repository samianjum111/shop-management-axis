from tenants.models import Tenant
from django.conf import settings
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
        ua = request.META.get('HTTP_USER_AGENT', '')
        if any(x in ua for x in ['Mobile', 'Android', 'iPhone', 'iPad']):
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
                try:
                    tenant = Tenant.objects.get(schema_name=schema)
                    if tenant.db_name:
                        # Ensure the database connection exists
                        if tenant.db_name not in settings.DATABASES:
                            # Copy default DB settings and set NAME
                            default_db = settings.DATABASES['default'].copy()
                            default_db['NAME'] = tenant.db_name
                            settings.DATABASES[tenant.db_name] = default_db
                        set_current_tenant_db(tenant.db_name)
                        request.tenant = tenant
                except Tenant.DoesNotExist:
                    pass
        response = self.get_response(request)
        set_current_tenant_db(None)
        return response
