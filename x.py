import subprocess
import sys
import os

def run(cmd):
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    return proc.returncode, out.decode().strip(), err.decode().strip()

def main():
    # Check if git repo
    if not os.path.isdir('.git'):
        print("❌ Not a git repository. Run this in your project root.")
        sys.exit(1)

    # Get current branch
    branch = subprocess.check_output(['git', 'rev-parse', '--abbrev-ref', 'HEAD']).decode().strip()
    
    # BADBOY WARNING: Agar main branch hai toh alert karo!
    if branch == "main":
        print("🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴")
        print("⚠️  WARNING: You are about to push directly to 'main'!")
        print("🔴 This is the LIVE PRODUCTION branch. Are you sure?")
        print("🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴")
    else:
        print(f"✅ Current branch: {branch}")

    msg = input("📝 Enter commit message: ").strip()
    if not msg:
        print("❌ Commit message cannot be empty.")
        sys.exit(1)

    print("➕ Adding changes...")
    subprocess.run(['git', 'add', '.'], check=False)

    print("💾 Committing...")
    code, out, err = run(['git', 'commit', '-m', msg])
    if code != 0:
        print(f"❌ Commit failed: {err}")
        sys.exit(1)
    print("✅ Commit successful.")

    print(f"🚀 Pushing to origin/{branch}...")
    code, out, err = run(['git', 'push', 'origin', branch])
    if code != 0:
        print(f"❌ Push failed: {err}")
        sys.exit(1)
    print("✅ Push successful!")
    print(f"📌 Changes pushed to branch: {branch}")

if __name__ == "__main__":
    main()
