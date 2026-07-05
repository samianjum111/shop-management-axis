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
    print("🚀 Fixing tenant database connection (adding OPTIONS key)...")

    admin_path = "users/admin.py"
    with open(admin_path, 'r') as f:
        content = f.read()

    # Find the part where settings.DATABASES[shop.db_name] is assigned
    # We'll replace the dict with one that includes 'OPTIONS': {}
    pattern = r"settings\.DATABASES\[shop\.db_name\] = \{(.*?)\}"
    replacement = """settings.DATABASES[shop.db_name] = {
                    'ENGINE': 'django.db.backends.postgresql',
                    'NAME': shop.db_name,
                    'USER': settings.DATABASES['default']['USER'],
                    'PASSWORD': settings.DATABASES['default']['PASSWORD'],
                    'HOST': settings.DATABASES['default']['HOST'],
                    'PORT': settings.DATABASES['default']['PORT'],
                    'OPTIONS': {},
                }"""
    # Use DOTALL to match multiline
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    write_file(admin_path, new_content)
    print("✅ Updated users/admin.py with OPTIONS in tenant DB settings.")

    print("\n" + "="*60)
    print("✅ Fix applied!")
    print("👉 Restart server: python manage.py runserver 0.0.0.0:8000")
    print("👉 Try creating a Shop again – migrations should run now.")
    print("="*60)

if __name__ == "__main__":
    main()
