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
    print("🚀 Fixing tenant DB connection (copy default DB settings)...")

    admin_path = "users/admin.py"
    with open(admin_path, 'r') as f:
        content = f.read()

    # Find the part where we set settings.DATABASES[shop.db_name]
    # We'll replace that whole block with a version that copies default DB
    pattern = r"settings\.DATABASES\[shop\.db_name\] = \{(.*?)\n\s+\}"
    replacement = """                default_db = settings.DATABASES['default']
                settings.DATABASES[shop.db_name] = default_db.copy()
                settings.DATABASES[shop.db_name]['NAME'] = shop.db_name"""
    # Use DOTALL to match multiline
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    write_file(admin_path, new_content)
    print("✅ Updated users/admin.py to copy default DB settings.")

    print("\n" + "="*60)
    print("✅ Fix applied!")
    print("👉 Restart server: python manage.py runserver 0.0.0.0:8000")
    print("👉 Try creating a Shop again – migrations should run now.")
    print("="*60)

if __name__ == "__main__":
    main()
