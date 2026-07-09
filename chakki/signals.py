from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import ChakkiOrder, ChakkiCustomer

@receiver(post_save, sender=ChakkiOrder)
def delete_walkin_customer(sender, instance, **kwargs):
    # Walk‑in customers are no longer automatically deleted.
    # They remain in the system with their order history.
    pass
