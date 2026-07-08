#!/usr/bin/env python3
import re
import subprocess
from pathlib import Path

MODELS_PATH = Path("chakki/models.py")

def patch_models():
    if not MODELS_PATH.exists():
        print("❌ models.py not found")
        return

    with open(MODELS_PATH, "r") as f:
        content = f.read()

    # Remove 'unique=True' from the name field of ChakkiCategory
    # Pattern: name = models.CharField(max_length=50, unique=True, ...
    new_content = re.sub(
        r'(name\s*=\s*models\.CharField\(max_length=50),\s*unique=True,?\s*',
        r'\1, ',
        content
    )

    if new_content == content:
        print("⚠️  No change made – maybe the field is already fixed?")
        return

    with open(MODELS_PATH, "w") as f:
        f.write(new_content)

    print("✅ Removed global unique constraint from ChakkiCategory.name")

def run_migrations():
    print("🔄 Creating migration...")
    subprocess.run(["python", "manage.py", "makemigrations", "chakki"], check=True)
    print("🔄 Applying migration...")
    subprocess.run(["python", "manage.py", "migrate", "chakki"], check=True)
    print("✅ Migration applied successfully.")

if __name__ == "__main__":
    patch_models()
    run_migrations()
