#!/usr/bin/env python3
import os
import sys
import subprocess
import time

PROJECT_DIR = "/var/www/shop-management-axis"
VENV_PYTHON = os.path.join(PROJECT_DIR, "venv/bin/python")
MANAGE_PY = os.path.join(PROJECT_DIR, "manage.py")

def run_command(cmd, cwd=PROJECT_DIR):
    print(f"🔄 Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print("❌ Command failed:")
        print(result.stdout)
        print(result.stderr)
        sys.exit(1)
    else:
        print(result.stdout)
    return result

def main():
    # 1. Change to project directory
    os.chdir(PROJECT_DIR)
    
    # 2. Pull latest code from GitHub (main branch)
    print("📥 Pulling latest changes from GitHub...")
    run_command(["git", "pull", "origin", "main"])
    
    # 3. Run migrations (if any)
    print("🔄 Running migrations for all schemas...")
    run_command([VENV_PYTHON, MANAGE_PY, "migrate_schemas", "--noinput"])
    
    # 4. Restart Gunicorn
    print("🔄 Restarting Gunicorn...")
    # Kill existing Gunicorn processes
    subprocess.run(["pkill", "-f", "gunicorn"], check=False)
    time.sleep(1)  # give it a moment to shut down
    # Start new Gunicorn in background
    gunicorn_cmd = [
        "nohup", "gunicorn", "saas_system.wsgi:application",
        "--workers=2", "--threads=4", "--bind", "0.0.0.0:8000",
        "&"
    ]
    subprocess.Popen(" ".join(gunicorn_cmd), shell=True, cwd=PROJECT_DIR)
    print("✅ Gunicorn restarted successfully.")
    print("🎉 Deployment complete!")

if __name__ == "__main__":
    main()
