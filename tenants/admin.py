from django.contrib import admin
from django import forms
from django.utils.html import format_html
from django.contrib.auth.models import User
from .models import Tenant

class TenantAdminForm(forms.ModelForm):
    admin_username = forms.CharField(max_length=150, required=True, label="Admin Username")
    admin_password = forms.CharField(widget=forms.PasswordInput, required=True, label="Admin Password")

    class Meta:
        model = Tenant
        fields = ['name', 'schema_name', 'category']
        exclude = ['owner', 'db_name', 'db_user', 'db_password']

    def save(self, commit=True):
        tenant = super().save(commit=False)
        if not tenant.pk:
            # Single-tenant mode: don't create a new database.
            tenant.db_name = 'default'
            tenant.db_user = 'default_user'
            tenant.db_password = 'dummy_password'
        if commit:
            tenant.save()
        return tenant

@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    form = TenantAdminForm
    list_display = ('name', 'schema_name', 'category', 'db_name', 'portal_links')
    search_fields = ('name', 'schema_name')
    readonly_fields = ('db_name', 'db_user', 'db_password')
    fieldsets = (
        (None, {'fields': ('name', 'schema_name', 'category')}),
        ('Portal Credentials', {'fields': ('admin_username', 'admin_password')}),
    )

    def save_model(self, request, obj, form, change):
        if not obj.owner:
            obj.owner = request.user
        super().save_model(request, obj, form, change)

    def portal_links(self, obj):
        if obj and obj.schema_name:
            desktop_url = f'/portal/{obj.schema_name}/'
            mobile_url = f'/portal/{obj.schema_name}/?mobile=1'
            return format_html(
                '<a href="{}" target="_blank" class="button">🖥️ Desktop</a>&nbsp;&nbsp;'
                '<a href="{}" target="_blank" class="button">📱 Mobile</a>',
                desktop_url, mobile_url
            )
        return "-"
    portal_links.short_description = "Portal Access"
