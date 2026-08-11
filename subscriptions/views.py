from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib import messages
from django.utils import timezone
from django.db import transaction
from datetime import timedelta
from tenants.models import Tenant
from .models import SubscriptionRequest

# ---------- Tenant-facing views ----------
def payment_required(request, schema_name):
    tenant = request.tenant
    if not tenant:
        return redirect('/')
    if tenant.is_subscription_active():
        return redirect('portal_dashboard', schema_name=schema_name)

    context = {
        'tenant': tenant,
        'jazzcash_number': tenant.jazzcash_number,
        'jazzcash_name': tenant.jazzcash_name,
        'amount': tenant.subscription_amount,
        'duration_days': tenant.subscription_duration_days,
    }
    template = 'mobile/subscription_payment.html' if request.mobile else 'desktop/subscription_payment.html'
    return render(request, template, context)

def upload_screenshot(request, schema_name):
    tenant = request.tenant
    if request.method == 'POST':
        screenshot = request.FILES.get('screenshot')
        if not screenshot:
            messages.error(request, "Please select a screenshot to upload.")
            return redirect('subscription_payment', schema_name=schema_name)

        with transaction.atomic():
            req = SubscriptionRequest.objects.create(
                tenant=tenant,
                screenshot=screenshot,
                status='pending'
            )
        messages.success(request, "Screenshot uploaded successfully. Our team will review it shortly.")
        return redirect('subscriptions:subscription_processing', schema_name=schema_name)
    return redirect('subscription_payment', schema_name=schema_name)

def processing_page(request, schema_name):
    tenant = request.tenant
    latest_req = tenant.subscription_requests.first()
    context = {
        'tenant': tenant,
        'latest_request': latest_req,
    }
    template = 'mobile/subscription_processing.html' if request.mobile else 'desktop/subscription_processing.html'
    return render(request, template, context)

# ---------- Admin review views ----------
@staff_member_required
def review_subscriptions(request):
    if not request.user.is_superuser:
        messages.error(request, "You do not have permission to access this page.")
        return redirect('/admin/')

    pending_requests = SubscriptionRequest.objects.filter(status='pending').select_related('tenant')
    approved_requests = SubscriptionRequest.objects.filter(status='approved').select_related('tenant')[:20]
    rejected_requests = SubscriptionRequest.objects.filter(status='rejected').select_related('tenant')[:20]

    context = {
        'pending_requests': pending_requests,
        'approved_requests': approved_requests,
        'rejected_requests': rejected_requests,
    }
    return render(request, 'admin/review_subscriptions.html', context)

@staff_member_required
def approve_request(request, request_id):
    if not request.user.is_superuser:
        messages.error(request, "Permission denied.")
        return redirect('review_subscriptions')

    req = get_object_or_404(SubscriptionRequest, id=request_id)
    if req.status != 'pending':
        messages.warning(request, "This request has already been processed.")
        return redirect('review_subscriptions')

    with transaction.atomic():
        req.status = 'approved'
        req.processed_at = timezone.now()
        req.save()
        tenant = req.tenant
        if tenant.subscription_duration_days:
            tenant.subscription_end_date = timezone.now() + timedelta(days=tenant.subscription_duration_days)
            tenant.save()
        else:
            messages.warning(request, f"Tenant {tenant.name} has no duration set. Subscription not extended.")
    messages.success(request, f"Subscription for {tenant.name} approved and extended.")
    return redirect('review_subscriptions')

@staff_member_required
def reject_request(request, request_id):
    if not request.user.is_superuser:
        messages.error(request, "Permission denied.")
        return redirect('review_subscriptions')

    req = get_object_or_404(SubscriptionRequest, id=request_id)
    if req.status != 'pending':
        messages.warning(request, "This request has already been processed.")
        return redirect('review_subscriptions')

    req.status = 'rejected'
    req.processed_at = timezone.now()
    req.save()
    messages.success(request, f"Subscription request for {req.tenant.name} rejected.")
    return redirect('review_subscriptions')
