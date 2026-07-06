#!/usr/bin/env python3
import os
import re
import json

# 1. Fix requirements.txt: replace invalid Django version
req_path = 'requirements.txt'
with open(req_path, 'r') as f:
    content = f.read()
content = re.sub(r'Django==6\.0\.6', 'Django==5.0.6', content)
with open(req_path, 'w') as f:
    f.write(content)
print("✅ Updated requirements.txt (Django 5.0.6)")

# 2. Create railway.json to disable collectstatic during build
railway_config = {
    "$schema": "https://railway.app/railway.schema.json",
    "build": {
        "builder": "NIXPACKS"
    },
    "deploy": {
        "numReplicas": 1,
        "restartPolicyType": "ON_FAILURE",
        "restartPolicyMaxRetries": 10,
        "env": {
            "DISABLE_COLLECTSTATIC": "1"
        }
    }
}
with open('railway.json', 'w') as f:
    json.dump(railway_config, f, indent=2)
print("✅ Created railway.json (DISABLE_COLLECTSTATIC=1)")

# 3. Create Procfile to run migrations + collectstatic at startup
procfile_content = "web: python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn saas_system.wsgi"
with open('Procfile', 'w') as f:
    f.write(procfile_content)
print("✅ Created Procfile")

print("\n🎉 All patches applied. Now commit and push:")
print("    git add .")
print("    git commit -m 'Fix deployment'")
print("    git push origin main")
