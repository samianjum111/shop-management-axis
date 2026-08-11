from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone
from datetime import timedelta
from .models import Tenant

@receiver(post_save, sender=Tenant)
def set_initial_subscription_end(sender, instance, created, **kwargs):
    if created and instance.schema_name != 'public':
        if instance.subscription_end_date is None:
            instance.subscription_end_date = timezone.now() + timedelta(days=instance.subscription_duration_days)
            instance.save()
