#!/usr/bin/env python3
import os
import sys
import subprocess

def main():
    if len(sys.argv) < 2:
        print("❌ Usage: python3 migrate_tenant.py <schema_name>")
        sys.exit(1)

    schema_name = sys.argv[1]

    # 1. Ensure the schema exists
    print(f"🔄 Creating schema '{schema_name}' if not exists...")
    subprocess.run(
        ["python", "manage.py", "migrate_schemas", "--schema", schema_name, "--noinput"],
        check=True
    )

    print(f"✅ Tenant '{schema_name}' migrated successfully.")
    print(f"🔗 Now visit: http://149.56.80.98/portal/{schema_name}/")

if __name__ == "__main__":
    main()
