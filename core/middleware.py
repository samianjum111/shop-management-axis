from tenants.models import Tenant
from django.http import Http404
from django.db import connection

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
        from tenants.models import Tenant
        try:
            if path.startswith('/portal/'):
                parts = path.split('/')
                if len(parts) >= 3:
                    schema_name = parts[2]
                    tenant = Tenant.objects.get(schema_name=schema_name)
                    request.tenant = tenant
                    connection.set_tenant(tenant)   # <-- switch schema
                else:
                    request.tenant = None
            else:
                # For admin and other non-portal paths, use public tenant
                tenant = Tenant.objects.get(schema_name='public')
                request.tenant = tenant
                connection.set_tenant(tenant)      # <-- switch to public
        except Tenant.DoesNotExist:
            request.tenant = None
        response = self.get_response(request)
        return response

    def process_response(self, request, response):
        # Reset schema to public after each request
        connection.set_schema_to_public()
        return response
