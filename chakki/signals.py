from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import ChakkiOrder, ChakkiCustomer

@receiver(post_save, sender=ChakkiOrder)
def delete_walkin_customer(sender, instance, **kwargs):
    # If order is completed and fully paid
    if instance.status == 'completed' and instance.payment_status == 'paid':
        customer = instance.customer
        # Only if it's a walk-in (not regular) and this is its only order
        if not customer.is_regular and customer.chakkiorder_set.count() == 1:
            customer.delete()
            print(f"🗑️ Deleted walk-in customer {customer.name} (no pending orders)")
