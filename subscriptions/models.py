from django.db import models
from django.conf import settings
from tenants.models import Tenant

class SubscriptionRequest(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending Review'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    )
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, related_name='subscription_requests')
    request_date = models.DateTimeField(auto_now_add=True)
    screenshot = models.ImageField(upload_to='subscription_screenshots/')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    admin_notes = models.TextField(blank=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.tenant.name} - {self.request_date.strftime('%Y-%m-%d %H:%M')}"

    class Meta:
        ordering = ['-request_date']
