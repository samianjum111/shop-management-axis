def tenant_processor(request):
    return {'tenant': getattr(request, 'tenant', None)}

from chakki.models import ChakkiOrder

def chakki_counts(request):
    from chakki.models import ChakkiOrder
    # Filter by tenant if available
    if hasattr(request, 'tenant') and request.tenant:
        orders = ChakkiOrder.objects.filter(tenant=request.tenant)
    else:
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


from django.utils import timezone
def today_context(request):
    return {'today': timezone.now().date()}
