#!/usr/bin/env python3
"""
Auto‑patcher for Wasmer/Shipit Django deployment.
Fixes psycopg2-binary error AND adds a correct 'serve' command.
"""

import json
import re
from pathlib import Path

PROJECT_ROOT = Path.cwd()
REQUIREMENTS = PROJECT_ROOT / "requirements.txt"
SHIPIT_FILE = PROJECT_ROOT / "Shipit"

def patch_requirements():
    """Replace psycopg2-binary with psycopg2."""
    if not REQUIREMENTS.exists():
        print("❌ requirements.txt not found.")
        return False

    content = REQUIREMENTS.read_text()
    if "psycopg2-binary" not in content:
        print("ℹ️  psycopg2-binary not found – nothing to patch.")
        return True

    new_content = re.sub(r"psycopg2-binary\s*==?\s*[\d.]+", "psycopg2", content)
    if "psycopg2" not in new_content:
        new_content += "\npsycopg2\n"
    REQUIREMENTS.write_text(new_content)
    print("✅ requirements.txt patched: psycopg2-binary → psycopg2")
    return True

def generate_shipit():
    """Create a Shipit file with both 'install' and 'serve' commands."""
    config = {
        "name": "out",
        "commands": {
            "install": "pip install -r requirements.txt",
            "serve": (
                "python manage.py migrate --noinput && "
                "python manage.py collectstatic --noinput && "
                "uvicorn saas_system.asgi:application --host 0.0.0.0 --port 8000"
            )
        },
        "framework": "django",
        "server": "uvicorn",
        "migration_strategy": "django",
        "database": "postgresql",
        "extra_dependencies": ["uvicorn"],
        "wsgi_application": "saas_system.wsgi:application",
        "install_inputs": ["requirements.txt"]
    }

    # If a Shipit file already exists, we can merge or overwrite.
    if SHIPIT_FILE.exists():
        try:
            existing = json.loads(SHIPIT_FILE.read_text())
            # Preserve any extra fields, but ensure commands are correct
            existing.setdefault("commands", {})
            existing["commands"]["install"] = config["commands"]["install"]
            existing["commands"]["serve"] = config["commands"]["serve"]
            # Ensure other fields are present if missing
            for key, value in config.items():
                if key not in existing:
                    existing[key] = value
            config = existing
        except json.JSONDecodeError:
            print("⚠️  Existing Shipit is invalid – overwriting with new one.")
    else:
        print("ℹ️  No Shipit file found – creating a new one.")

    with SHIPIT_FILE.open("w") as f:
        json.dump(config, f, indent=2)

    print("✅ Shipit file created/updated with 'serve' and 'install' commands.")

def main():
    print("🚀 Wasmer Deployment Patcher (fixed Shipit)")
    print("────────────────────────────────────────────")
    if patch_requirements():
        generate_shipit()
        print("\n🎉 All patches applied!")
        print("📌 Commit and push, then redeploy to Wasmer.")
        print("   Your Shipit now uses 'serve' – the error should be gone.")
    else:
        print("❌ Patching failed. Check that you are in the project root.")

if __name__ == "__main__":
    main()
