from django.contrib import admin
from django import forms
from django.contrib.auth import get_user_model
from .models import Tenant

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
            # Create the tenant first
            tenant.save()
            # Create the admin user in the public schema (or the tenant's schema if needed)
            # For now, we create the user in the default database (public schema)
            User.objects.create_superuser(
                username=self.cleaned_data['admin_username'],
                password=self.cleaned_data['admin_password'],
                email=''
            )
        else:
            tenant.save()
        return tenant

@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    form = TenantAdminForm
    list_display = ('name', 'schema_name', 'category', 'created_at')
    readonly_fields = ('created_at',)
