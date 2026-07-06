#!/usr/bin/env python3
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 1. requirements.txt
requirements = """Django==6.0.6
psycopg2-binary
whitenoise
gunicorn
python-dotenv
"""
with open(os.path.join(BASE_DIR, 'requirements.txt'), 'w') as f:
    f.write(requirements)

# 2. Procfile (for gunicorn)
procfile = "web: gunicorn saas_system.wsgi"
with open(os.path.join(BASE_DIR, 'Procfile'), 'w') as f:
    f.write(procfile)

# 3. runtime.txt (Python version)
runtime = "python-3.12"
with open(os.path.join(BASE_DIR, 'runtime.txt'), 'w') as f:
    f.write(runtime)

print("✅ Railway deployment files created.")
print("📌 Now run: git add . && git commit -m 'Add Railway files' && git push origin main")
