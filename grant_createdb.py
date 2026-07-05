import subprocess
import sys

def main():
    print("🚀 Granting CREATEDB privilege to saas_user...")
    try:
        # Run as postgres superuser (no password required due to peer auth)
        cmd = "sudo -u postgres psql -c \"ALTER USER saas_user CREATEDB;\""
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print("❌ Error executing command:", result.stderr)
            print("👉 Please manually run: sudo -u postgres psql -c \"ALTER USER saas_user CREATEDB;\"")
            sys.exit(1)
        print("✅ CREATEDB privilege granted to saas_user.")
        print("👉 Now restart server and try creating a Shop again.")
    except Exception as e:
        print("❌ Exception:", e)
        print("👉 Please manually run: sudo -u postgres psql -c \"ALTER USER saas_user CREATEDB;\"")
        sys.exit(1)

if __name__ == "__main__":
    main()
