from django.contrib import admin
from .models import SubscriptionRequest

@admin.register(SubscriptionRequest)
class SubscriptionRequestAdmin(admin.ModelAdmin):
    list_display = ('tenant', 'request_date', 'status', 'processed_at')
    list_filter = ('status', 'tenant')
    search_fields = ('tenant__name', 'tenant__schema_name')
    readonly_fields = ('request_date', 'screenshot')
    actions = ['approve_selected', 'reject_selected']

    def approve_selected(self, request, queryset):
        from django.utils import timezone
        from datetime import timedelta
        for obj in queryset:
            obj.status = 'approved'
            obj.processed_at = timezone.now()
            tenant = obj.tenant
            if tenant.subscription_duration_days:
                tenant.subscription_end_date = timezone.now() + timedelta(days=tenant.subscription_duration_days)
                tenant.save()
            obj.save()
        self.message_user(request, f"{queryset.count()} requests approved.")
    approve_selected.short_description = "Approve selected requests"

    def reject_selected(self, request, queryset):
        from django.utils import timezone
        for obj in queryset:
            obj.status = 'rejected'
            obj.processed_at = timezone.now()
            obj.save()
        self.message_user(request, f"{queryset.count()} requests rejected.")
    reject_selected.short_description = "Reject selected requests"
