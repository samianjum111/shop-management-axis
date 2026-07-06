import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
django.setup()

from django.conf import settings
from tenants.models import Tenant
from chakki.models import ChakkiOrder
from django.utils import timezone

def fix_orders():
    for tenant in Tenant.objects.all():
        db_name = tenant.db_name
        if db_name not in settings.DATABASES:
            default_db = settings.DATABASES['default'].copy()
            default_db['NAME'] = db_name
            settings.DATABASES[db_name] = default_db
        print(f"  Fixing orders for {tenant.schema_name}...")
        orders = ChakkiOrder.objects.using(db_name).all()
        for order in orders:
            total = order.total_amount
            paid = order.amount_paid
            if paid == 0:
                payment_status = 'unpaid'
                status = 'pending' if order.status != 'completed' else order.status
                completed_at = None
            elif total > 0 and paid >= total:
                payment_status = 'paid'
                paid = total
                status = 'completed'
                completed_at = timezone.now() if not order.completed_at else order.completed_at
            else:
                payment_status = 'partial'
                status = 'pending'
                completed_at = None
            ChakkiOrder.objects.using(db_name).filter(pk=order.pk).update(
                amount_paid=paid,
                payment_status=payment_status,
                status=status,
                completed_at=completed_at if status == 'completed' else None
            )
    print("✅ Data fix completed.")

if __name__ == "__main__":
    fix_orders()
