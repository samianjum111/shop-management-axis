import os
import re
import sys

BASE_DIR = os.getcwd()

def write_file(path, content):
    path = os.path.join(BASE_DIR, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

def main():
    print("🚀 Applying Debug Patcher for Admin Form...")

    # 1. Fix .env DB_NAME to 'saas_db' if not already
    env_path = ".env"
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            env_content = f.read()
        # Replace DB_NAME line
        env_content = re.sub(r'DB_NAME=.*', 'DB_NAME=saas_db', env_content)
        write_file(env_path, env_content)
        print("✅ Updated .env: DB_NAME set to saas_db")
    else:
        print("⚠️ .env file not found. Please set DB_NAME=saas_db manually.")

    # 2. Update users/admin.py with debug logging
    admin_path = "users/admin.py"
    with open(admin_path, 'r') as f:
        admin_content = f.read()

    # Replace the save method with a debug version
    new_save = '''
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
'''
    # Replace the old save method with the new one
    # Find the old save method and replace
    pattern = r'def save\(self, commit=True\):.*?(?=\n    def |\n\n    def |\Z)'
    admin_content = re.sub(pattern, new_save, admin_content, flags=re.DOTALL)
    write_file(admin_path, admin_content)
    print("✅ Updated users/admin.py with debug logging.")

    print("\n" + "="*60)
    print("✅ Debug patcher applied!")
    print("👉 Now restart server: python manage.py runserver 0.0.0.0:8000")
    print("👉 Try creating a Shop again.")
    print("👉 The terminal will show detailed logs of each step.")
    print("👉 If error occurs, copy the full traceback and paste here.")
    print("="*60)

if __name__ == "__main__":
    main()
