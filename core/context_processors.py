def tenant_processor(request):
    return {'tenant': getattr(request, 'tenant', None)}

from chakki.models import ChakkiOrder

def chakki_counts(request):
    from chakki.models import ChakkiOrder
    tenant = getattr(request, 'tenant', None)
    # For admin/public schema, return empty counts to avoid table errors
    if tenant is None or (hasattr(tenant, 'schema_name') and tenant.schema_name == 'public'):
        orders = ChakkiOrder.objects.none()
    else:
        orders = ChakkiOrder.objects.filter(tenant=tenant)
    
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
