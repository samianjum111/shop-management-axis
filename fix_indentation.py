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
    print("🚀 Fixing indentation in users/admin.py...")

    admin_path = "users/admin.py"
    with open(admin_path, 'r') as f:
        content = f.read()

    # Find the save method and fix indentation of default_db lines
    # We'll replace the block that sets default_db with proper indentation
    pattern = r"(                )default_db = settings\.DATABASES\['default'\]\n(                )settings\.DATABASES\[shop\.db_name\] = default_db\.copy\(\)\n(                )settings\.DATABASES\[shop\.db_name\]\['NAME'\] = shop\.db_name"
    replacement = r"\1default_db = settings.DATABASES['default']\n\1settings.DATABASES[shop.db_name] = default_db.copy()\n\1settings.DATABASES[shop.db_name]['NAME'] = shop.db_name"
    new_content = re.sub(pattern, replacement, content)

    # Also check if there are extra spaces, we'll just replace the whole method with a corrected version.
    # But to be safe, we'll use the pattern above and if it doesn't match, we'll use a broader approach.
    if new_content == content:
        # If pattern didn't match, we'll search for the lines and replace manually.
        # We'll find the lines containing default_db and fix indentation.
        lines = content.splitlines()
        new_lines = []
        for line in lines:
            if "default_db = settings.DATABASES['default']" in line:
                # Fix indentation to 16 spaces (4 tabs or 16 spaces)
                # Count current indentation and adjust
                stripped = line.lstrip()
                # We want 16 spaces (4 levels of indentation)
                new_lines.append("                " + stripped)
            elif "settings.DATABASES[shop.db_name] = default_db.copy()" in line:
                new_lines.append("                " + line.lstrip())
            elif "settings.DATABASES[shop.db_name]['NAME'] = shop.db_name" in line:
                new_lines.append("                " + line.lstrip())
            else:
                new_lines.append(line)
        new_content = "\n".join(new_lines)

    write_file(admin_path, new_content)
    print("✅ Indentation fixed in users/admin.py.")

    print("\n" + "="*60)
    print("✅ Fix applied!")
    print("👉 Restart server: python manage.py runserver 0.0.0.0:8000")
    print("👉 Try creating a Shop again – it should work now.")
    print("="*60)

if __name__ == "__main__":
    main()
