from tenants.models import Tenant
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
                from tenants.models import Tenant
                try:
                    tenant = Tenant.objects.get(schema_name=schema_name)
                    request.tenant = tenant
                except Tenant.DoesNotExist:
                    raise Http404("Tenant not found")
        else:
            request.tenant = None
        response = self.get_response(request)
        return response
