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
        path = request.path_info

        # Exempt static/media/admin
        exempt_paths = [
            '/static/',
            '/media/',
            '/admin/',
            '/admin/subscriptions/review/',
        ]
        for exempt in exempt_paths:
            if path.startswith(exempt):
                return None

        # Exempt subscription URLs from subscription check (but still require login)
        if path.startswith('/portal/') and '/subscription/' in path:
            if not request.user.is_authenticated:
                login_url = reverse('portal_login', kwargs={'schema_name': tenant.schema_name})
                return HttpResponseRedirect(f'{login_url}?next={path}')
            return None  # allow access (payment/upload/processing)

        # Exempt the login page itself
        portal_root = f'/portal/{tenant.schema_name}/'
        if path == portal_root or path == portal_root.rstrip('/'):
            return None

        # Check authentication
        if not request.user.is_authenticated:
            login_url = reverse('portal_login', kwargs={'schema_name': tenant.schema_name})
            return HttpResponseRedirect(f'{login_url}?next={path}')

        # Now check subscription
        if not tenant.is_subscription_active():
            from .models import SubscriptionRequest
            pending_req = SubscriptionRequest.objects.filter(tenant=tenant, status='pending').first()
            if pending_req:
                processing_url = reverse('subscriptions:subscription_processing', kwargs={'schema_name': tenant.schema_name})
                return HttpResponseRedirect(processing_url)
            else:
                payment_url = reverse('subscriptions:subscription_payment', kwargs={'schema_name': tenant.schema_name})
                return HttpResponseRedirect(payment_url)

        return None
