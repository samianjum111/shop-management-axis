from django.shortcuts import render
from django.urls import reverse
from django.http import HttpResponseRedirect
from tenants.models import Tenant

class SubscriptionMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        return response

    def process_view(self, request, view_func, view_args, view_kwargs):
        if not request.tenant:
            return None

        tenant = request.tenant
        exempt_paths = [
            '/static/',
            '/media/',
            '/admin/',
        ]
        path = request.path_info
        if path.startswith('/portal/') and '/subscription/' in path:
            return None

        for exempt in exempt_paths:
            if path.startswith(exempt):
                return None

        if not tenant.is_subscription_active():
            payment_url = reverse('subscriptions:subscription_payment', kwargs={'schema_name': tenant.schema_name})
            return HttpResponseRedirect(payment_url)

        return None
