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
    print("🚀 Fixing Tenant Admin to show username/password fields...")

    admin_path = "tenants/admin.py"
    with open(admin_path, 'r') as f:
        content = f.read()

    # Update the TenantAdmin class to include fieldsets with credentials
    pattern = r'(@admin\.register\(Tenant\)\nclass TenantAdmin.*?)(?=\n\n|$)'
    replacement = '''
@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    form = TenantAdminForm
    list_display = ('name', 'schema_name', 'db_name', 'owner', 'created_at')
    search_fields = ('name', 'schema_name', 'db_name')
    readonly_fields = ('db_name', 'db_user', 'db_password')
    fieldsets = (
        (None, {'fields': ('name', 'schema_name')}),
        ('Portal Credentials', {'fields': ('admin_username', 'admin_password'), 'classes': ('collapse',)}),
        ('Owner', {'fields': ('owner',)}),
    )
'''
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    write_file(admin_path, new_content)
    print("✅ TenantAdmin updated with fieldsets for credentials.")

    print("\n" + "="*60)
    print("✅ Fix applied!")
    print("👉 Restart server: python manage.py runserver 0.0.0.0:8000")
    print("👉 Now go to /admin/tenants/tenant/add/ – you should see admin_username and admin_password fields.")
    print("👉 Enter them and save to create tenant.")
    print("="*60)

if __name__ == "__main__":
    main()
