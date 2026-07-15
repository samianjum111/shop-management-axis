from django.db.models import Count, Q
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
    
    counts = orders.aggregate(
        pending_count=Count('id', filter=Q(status='pending')),
        ready_count=Count('id', filter=Q(status='ready')),
        partial_count=Count('id', filter=Q(payment_status='partial')),
        completed_count=Count('id', filter=Q(status='completed')),
    )
    pending_count = counts['pending_count']
    ready_count = counts['ready_count']
    partial_count = counts['partial_count']
    completed_count = counts['completed_count']
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