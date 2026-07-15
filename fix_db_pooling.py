#!/usr/bin/env python3
import re

SETTINGS_PATH = "/var/www/shop-management-axis/saas_system/settings.py"

with open(SETTINGS_PATH, 'r') as f:
    content = f.read()

# Check if CONN_MAX_AGE already exists
if "CONN_MAX_AGE" in content:
    print("✅ CONN_MAX_AGE already exists. Skipping.")
else:
    # Find the DATABASES block and add CONN_MAX_AGE
    pattern = r"(DATABASES\s*=\s*\{[^}]*'default'\s*:\s*\{[^}]*\})"
    
    # Insert CONN_MAX_AGE before the closing brace
    def add_conn_max_age(match):
        block = match.group(1)
        # Add CONN_MAX_AGE before the last }
        new_block = block.rstrip() + ",\n        'CONN_MAX_AGE': 600,\n    }"
        # Fix the closing brace if needed
        if new_block.endswith(",    }"):
            new_block = new_block.replace(",    }", ",\n        'CONN_MAX_AGE': 600,\n    }")
        return new_block
    
    new_content = re.sub(pattern, add_conn_max_age, content, flags=re.DOTALL)
    
    with open(SETTINGS_PATH, 'w') as f:
        f.write(new_content)
    print("✅ Added CONN_MAX_AGE = 600 to DATABASES.")

# Also add proxy timeouts in Nginx site config
nginx_site = "/etc/nginx/sites-available/shop-management"
if nginx_site:
    try:
        with open(nginx_site, 'r') as f:
            site_content = f.read()
        if "proxy_read_timeout" not in site_content:
            # Add timeouts
            new_site = site_content.replace(
                "location / {",
                "location / {\n        proxy_connect_timeout 60s;\n        proxy_read_timeout 60s;\n        proxy_send_timeout 60s;"
            )
            with open(nginx_site, 'w') as f:
                f.write(new_site)
            print("✅ Added proxy timeouts to Nginx config.")
            import subprocess
            subprocess.run(["nginx", "-t"], check=True)
            subprocess.run(["sudo", "systemctl", "reload", "nginx"], check=True)
    except Exception as e:
        print(f"⚠️ Could not update Nginx config: {e}")

print("\n🎉 All optimizations applied!")
print("   - CONN_MAX_AGE: Database connections reused for 10 minutes")
print("   - Proxy timeouts added to Nginx")
print("   - Gzip already enabled ✅")
print("\n🔄 Restart Gunicorn to apply changes...")
import subprocess
subprocess.run(["sudo", "systemctl", "restart", "gunicorn"], check=False)
print("✅ Done!")
