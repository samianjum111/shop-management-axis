def tenant_processor(request):
    from tenants.models import Tenant
    dummy_tenant = Tenant(name='My Shop', schema_name='default', db_name='default')
    return {'tenant': getattr(request, 'tenant', dummy_tenant)}

from chakki.models import ChakkiOrder
def chakki_counts(request):
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
