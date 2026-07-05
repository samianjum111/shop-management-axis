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
    print("🚀 Fixing admin registration for Shop model...")

    admin_content = '''from django.contrib import admin
from django.contrib.auth.models import User
from django import forms
from django.utils.html import format_html
from django.core.exceptions import ValidationError
from django.conf import settings
from django.core.management import call_command
from .models import Shop
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

class ShopAdminForm(forms.ModelForm):
    admin_username = forms.CharField(max_length=150, required=True, help_text="Admin username for this shop (tenant DB)")
    admin_password = forms.CharField(widget=forms.PasswordInput, required=True, help_text="Admin password for this shop (tenant DB)")
    
    class Meta:
        model = Shop
        fields = '__all__'
        exclude = ['owner', 'db_name', 'db_user', 'db_password']

    def clean_schema_name(self):
        schema = self.cleaned_data.get('schema_name')
        if schema:
            schema = schema.strip()
            if ' ' in schema:
                raise ValidationError("Schema name cannot contain spaces.")
        return schema

    def save(self, commit=True):
        shop = super().save(commit=False)
        try:
            if not shop.pk:
                import secrets
                shop.db_name = f"shop_{secrets.token_hex(4)}"
                shop.db_user = f"user_{secrets.token_hex(4)}"
                shop.db_password = secrets.token_urlsafe(16)

                print(f"🔧 Creating database: {shop.db_name} ...")
                conn = psycopg2.connect(
                    dbname='postgres',
                    user=settings.DATABASES['default']['USER'],
                    password=settings.DATABASES['default']['PASSWORD'],
                    host=settings.DATABASES['default']['HOST'],
                    port=settings.DATABASES['default']['PORT']
                )
                conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
                cur = conn.cursor()
                cur.execute(f"CREATE DATABASE {shop.db_name} OWNER {settings.DATABASES['default']['USER']};")
                cur.close()
                conn.close()
                print(f"✅ Database {shop.db_name} created.")

                settings.DATABASES[shop.db_name] = {
                    'ENGINE': 'django.db.backends.postgresql',
                    'NAME': shop.db_name,
                    'USER': settings.DATABASES['default']['USER'],
                    'PASSWORD': settings.DATABASES['default']['PASSWORD'],
                    'HOST': settings.DATABASES['default']['HOST'],
                    'PORT': settings.DATABASES['default']['PORT'],
                }
                print("📦 Running migrations on new DB...")
                call_command('migrate', database=shop.db_name, verbosity=2, interactive=False)
                print("✅ Migrations done.")

                admin_username = self.cleaned_data.get('admin_username')
                admin_password = self.cleaned_data.get('admin_password')
                print(f"👤 Creating superuser {admin_username} in tenant DB...")
                User.objects.using(shop.db_name).create_superuser(
                    username=admin_username,
                    password=admin_password,
                    email=''
                )
                print("✅ Superuser created.")
            if commit:
                shop.save()
        except Exception as e:
            import traceback
            traceback.print_exc()
            raise ValidationError(f"Error creating shop: {str(e)}")
        return shop

@admin.register(Shop)
class ShopAdmin(admin.ModelAdmin):
    form = ShopAdminForm
    list_display = ('name', 'schema_name', 'db_name', 'category', 'phone', 'portal_links')
    search_fields = ('name', 'schema_name', 'db_name')
    readonly_fields = ('db_name', 'db_user', 'db_password')
    fieldsets = (
        (None, {'fields': ('name', 'schema_name', 'category', 'phone', 'address')}),
        ('Tenant Credentials', {'fields': ('admin_username', 'admin_password'), 'classes': ('collapse',)}),
    )

    def get_readonly_fields(self, request, obj=None):
        if obj:  # editing existing
            return self.readonly_fields
        return ('db_name', 'db_user', 'db_password')  # still readonly on add

    def portal_links(self, obj):
        if obj and obj.schema_name:
            desktop_url = f'/portal/{obj.schema_name}/'
            mobile_url = f'/portal/{obj.schema_name}/?mobile=1'
            return format_html(
                '<a href="{}" target="_blank" class="button">🖥️ Desktop Portal</a>&nbsp;&nbsp;'
                '<a href="{}" target="_blank" class="button">📱 Mobile Portal</a>',
                desktop_url, mobile_url
            )
        return "-"
    portal_links.short_description = "Portal Access"
'''
    write_file("users/admin.py", admin_content)
    print("✅ users/admin.py fixed.")

    print("\n" + "="*60)
    print("✅ Admin registration fixed!")
    print("👉 Restart server: python manage.py runserver 0.0.0.0:8000")
    print("👉 Now go to /admin/users/shop/ – it should show the Shop model.")
    print("👉 Try creating a Shop with admin_username and admin_password.")
    print("👉 Terminal will show detailed logs.")
    print("="*60)

if __name__ == "__main__":
    main()
