import os
import re

BASE_DIR = os.getcwd()

def write_file(path, content):
    path = os.path.join(BASE_DIR, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

def main():
    print("🚀 Applying simple admin fix...")

    # 1. Update tenants/models.py – add category field
    models_path = "tenants/models.py"
    with open(models_path, 'r') as f:
        models_content = f.read()
    
    # Add category field after name
    if "category" not in models_content:
        # Insert after name field
        models_content = models_content.replace(
            "name = models.CharField(max_length=100)",
            "name = models.CharField(max_length=100)\n    CATEGORY_CHOICES = [('chakki', 'Atta Chakki')]\n    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='chakki')"
        )
        write_file(models_path, models_content)
        print("✅ Added category field to Tenant model.")
    else:
        print("ℹ️ category field already exists.")

    # 2. Update tenants/admin.py – simple form with only needed fields
    admin_content = '''from django.contrib import admin
from django import forms
from django.conf import settings
from django.core.management import call_command
from django.utils.html import format_html
from .models import Tenant
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

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
            import secrets
            tenant.db_name = f"shop_{secrets.token_hex(4)}"
            tenant.db_user = f"user_{secrets.token_hex(4)}"
            tenant.db_password = secrets.token_urlsafe(16)

            # Create database
            conn = psycopg2.connect(
                dbname='postgres',
                user=settings.DATABASES['default']['USER'],
                password=settings.DATABASES['default']['PASSWORD'],
                host=settings.DATABASES['default']['HOST'],
                port=settings.DATABASES['default']['PORT']
            )
            conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
            cur = conn.cursor()
            cur.execute(f"CREATE DATABASE {tenant.db_name} OWNER {settings.DATABASES['default']['USER']};")
            cur.close()
            conn.close()

            # Add DB connection
            default_db = settings.DATABASES['default'].copy()
            default_db['NAME'] = tenant.db_name
            settings.DATABASES[tenant.db_name] = default_db

            # Run migrations on new DB (all apps except 'tenants')
            call_command('migrate', database=tenant.db_name, verbosity=2, interactive=False)

            # Create superuser in tenant DB
            User = __import__('django.contrib.auth').get_user_model()
            User.objects.using(tenant.db_name).create_superuser(
                username=self.cleaned_data['admin_username'],
                password=self.cleaned_data['admin_password'],
                email=''
            )
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
'''
    write_file("tenants/admin.py", admin_content)
    print("✅ tenants/admin.py updated with simple form and portal links.")

    print("\n" + "="*60)
    print("✅ Patcher applied successfully!")
    print("👉 Now run the following commands:")
    print("   python manage.py makemigrations tenants")
    print("   python manage.py migrate")
    print("   python manage.py runserver 0.0.0.0:8000")
    print("👉 Then go to /admin/tenants/tenant/add/ – you'll see only Name, Schema, Category, Username, Password.")
    print("👉 After saving, you'll see portal links in the list view.")
    print("="*60)

if __name__ == "__main__":
    main()
