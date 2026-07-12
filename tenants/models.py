from django.db import models
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.core.management import call_command
from django.db import connection

class Tenant(models.Model):
    name = models.CharField(max_length=100)
    schema_name = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    category = models.CharField(max_length=20, default='chakki')
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)


    # Subscription fields
    subscription_duration_days = models.IntegerField(default=30, help_text="Number of days per subscription period")
    subscription_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00, help_text="Amount to pay for one period")
    jazzcash_number = models.CharField(max_length=20, blank=True, help_text="JazzCash number for payment")
    jazzcash_name = models.CharField(max_length=100, blank=True, help_text="Account holder name for JazzCash")
    subscription_end_date = models.DateTimeField(null=True, blank=True, help_text="When the current subscription expires")

    def is_subscription_active(self):
        """Returns True if subscription is active (end_date is in the future or None)."""
        if self.subscription_end_date is None:
            return True
        from django.utils import timezone
        return timezone.now() < self.subscription_end_date

    def __str__(self):
        return self.name

@receiver(post_save, sender=Tenant)
def create_tenant_schema(sender, instance, created, **kwargs):
    """Auto‑create schema and run migrations when a new tenant is saved."""
    if not created:
        return
    if instance.schema_name == 'public':
        return

    try:
        # 1. Create schema if not exists
        with connection.cursor() as cursor:
            cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {instance.schema_name};")

        # 2. Switch to tenant schema
        connection.set_tenant(instance)

        # 3. Run migrations for this tenant
        call_command('migrate_schemas', schema=instance.schema_name, verbosity=0, interactive=False)

        # 4. Reset to public
        connection.set_schema_to_public()

        print(f"✅ Tenant '{instance.schema_name}' schema created and migrations applied.")
    except Exception as e:
        # If something fails, reset to public and re‑raise
        connection.set_schema_to_public()
        raise e
