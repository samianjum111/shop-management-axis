from django.contrib import admin
from django import forms
from django_tenants.admin import TenantAdminMixin
from django_tenants.utils import schema_context
from django.contrib.auth import get_user_model
from .models import Tenant, Domain

User = get_user_model()

class TenantAdminForm(forms.ModelForm):
    admin_username = forms.CharField(max_length=150, required=True, label="Admin Username")
    admin_password = forms.CharField(widget=forms.PasswordInput, required=True, label="Admin Password")

    class Meta:
        model = Tenant
        fields = ('name', 'schema_name', 'category')

    def save(self, commit=True):
        tenant = super().save(commit=False)
        if not tenant.pk:
            tenant.save()
            with schema_context(tenant.schema_name):
                User.objects.create_superuser(
                    username=self.cleaned_data['admin_username'],
                    password=self.cleaned_data['admin_password'],
                    email=''
                )
        else:
            tenant.save()
        return tenant

@admin.register(Tenant)
class TenantAdmin(TenantAdminMixin, admin.ModelAdmin):
    form = TenantAdminForm
    list_display = ('name', 'schema_name', 'category', 'created_at')
    fields = ('name', 'schema_name', 'category', 'created_at')
    readonly_fields = ('created_at',)

@admin.register(Domain)
class DomainAdmin(admin.ModelAdmin):
    list_display = ('domain', 'tenant', 'is_primary')
