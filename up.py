#!/usr/bin/env python3
import subprocess
import os

os.chdir("/var/www/shop-management-axis")

print("📦 Collecting static files...")
subprocess.run(["python", "manage.py", "collectstatic", "--noinput"], check=False)

print("🔄 Running migrations (if any)...")
subprocess.run(["python", "manage.py", "migrate_schemas", "--noinput"], check=False)

print("🔄 Restarting Gunicorn...")
subprocess.run(["sudo", "systemctl", "restart", "gunicorn"], check=True)

print("✅ Update complete! Visit http://149.56.80.98")
