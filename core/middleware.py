from tenants.models import Tenant

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
