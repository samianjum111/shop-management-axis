#!/usr/bin/env python3
import os

PULL_PATH = "/var/www/shop-management-axis/pull.py"
NEW_PG_DUMP = "/usr/lib/postgresql/17/bin/pg_dump"

if os.path.exists(PULL_PATH):
    with open(PULL_PATH, 'r') as f:
        content = f.read()
    # Replace any occurrence of "pg_dump" with the full path
    new_content = content.replace('"pg_dump"', f'"{NEW_PG_DUMP}"')
    with open(PULL_PATH, 'w') as f:
        f.write(new_content)
    print("✅ pull.py updated to use new pg_dump.")
else:
    print("⚠️ pull.py not found.")
