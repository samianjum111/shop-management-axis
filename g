#!/usr/bin/env python3
"""
Auto‑patcher for Wasmer/Shipit Django deployment.
Fixes "psycopg2-binary" not found for wasix_wasm32 platform.
"""

import re
from pathlib import Path

PROJECT_ROOT = Path.cwd()
REQUIREMENTS = PROJECT_ROOT / "requirements.txt"
SHIPIT_FILE = PROJECT_ROOT / "Shipit"          # no extension, JSON format

def patch_requirements():
    """Replace psycopg2-binary with psycopg2 in requirements.txt."""
    if not REQUIREMENTS.exists():
        print("❌ requirements.txt not found. Are you in the project root?")
        return False

    with REQUIREMENTS.open("r", encoding="utf-8") as f:
        content = f.read()

    # Check if psycopg2-binary is present
    if "psycopg2-binary" not in content:
        print("ℹ️  psycopg2-binary not found in requirements.txt. Nothing to patch.")
        return True

    # Replace with psycopg2
    new_content = re.sub(
        r"psycopg2-binary\s*==?\s*[\d.]+",   # matches exact or loose version
        "psycopg2",
        content
    )

    # Ensure psycopg2 is present (if it was removed entirely)
    if "psycopg2" not in new_content:
        new_content += "\npsycopg2\n"

    with REQUIREMENTS.open("w", encoding="utf-8") as f:
        f.write(new_content)

    print("✅ requirements.txt patched: psycopg2-binary → psycopg2")
    return True


def create_shipit():
    """Create/update a Shipit file that overrides the install command."""
    # Base config from the user's deployment log
    config = {
        "name": "out",
        "commands": {
            "start": "python manage.py migrate --noinput && python manage.py collectstatic --noinput && uvicorn saas_system.asgi:application --host 0.0.0.0 --port 8000"
        },
        "framework": "django",
        "server": "uvicorn",
        "migration_strategy": "django",
        "database": "postgresql",
        "extra_dependencies": [
            "uvicorn"
        ],
        "wsgi_application": "saas_system.wsgi:application",
        "install_inputs": [
            "requirements.txt"
        ]
    }

    # If Shipit file already exists, we can merge or replace.
    # We'll read it and update only the commands.install field.
    if SHIPIT_FILE.exists():
        import json
        with SHIPIT_FILE.open("r", encoding="utf-8") as f:
            try:
                existing = json.load(f)
                # Override or add install command
                existing.setdefault("commands", {})["install"] = "pip install -r requirements.txt"
                # Preserve other fields, but ensure important ones are present
                for key, value in config.items():
                    if key not in existing:
                        existing[key] = value
                config = existing
            except json.JSONDecodeError:
                print("⚠️  Existing Shipit file is not valid JSON. Overwriting with new config.")
    else:
        # New file: add install command
        config["commands"]["install"] = "pip install -r requirements.txt"

    import json
    with SHIPIT_FILE.open("w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)

    print("✅ Shipit file created/updated with custom install command (pip install).")


def main():
    print("🚀 Wasmer Deployment Patcher")
    print("─────────────────────────────")

    if not patch_requirements():
        return

    create_shipit()

    print("\n🎉 Patches applied successfully!")
    print("📌 Now commit the changes and redeploy to Wasmer.")
    print("   (Run: git add . && git commit -m 'Fix psycopg2 for WASM' && git push)")
    print("   Then trigger a new deployment.")


if __name__ == "__main__":
    main()
