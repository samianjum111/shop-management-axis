#!/usr/bin/env python3
import subprocess
import os

SERVICE_FILE = "/etc/systemd/system/gunicorn.service"
ENV_FILE = "/var/www/shop-management-axis/.env"

# Correct service file content
SERVICE_CONTENT = f'''[Unit]
Description=Gunicorn server for shop-management-axis
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=/var/www/shop-management-axis
Environment="PATH=/var/www/shop-management-axis/venv/bin"
Environment="DJANGO_SETTINGS_MODULE=saas_system.settings"
EnvironmentFile={ENV_FILE}
ExecStart=/var/www/shop-management-axis/venv/bin/gunicorn saas_system.wsgi:application --workers=2 --threads=4 --bind 0.0.0.0:8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
'''

# Write the service file
with open(SERVICE_FILE, 'w') as f:
    f.write(SERVICE_CONTENT)
print("✅ Updated gunicorn.service")

# Reload systemd
subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)

# Stop, kill leftover processes, start
subprocess.run(["sudo", "systemctl", "stop", "gunicorn"], check=False)
subprocess.run(["pkill", "-f", "gunicorn"], check=False)
subprocess.run(["sudo", "systemctl", "start", "gunicorn"], check=True)

print("✅ Gunicorn restarted with proper environment.")

# Check status
status = subprocess.run(["sudo", "systemctl", "status", "gunicorn"], capture_output=True, text=True)
print(status.stdout)
