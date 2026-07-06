#!/usr/bin/env python3
import os
import re

VIEWS_FILE = 'chakki/views.py'

def fix_redirects():
    if not os.path.exists(VIEWS_FILE):
        print(f"❌ File not found: {VIEWS_FILE}")
        return False

    with open(VIEWS_FILE, 'r') as f:
        content = f.read()

    # Replace 'chakki_dashboard' with 'portal_dashboard' in redirect calls
    new_content = content.replace("redirect('chakki_dashboard',", "redirect('portal_dashboard',")
    new_content = new_content.replace('redirect("chakki_dashboard",', 'redirect("portal_dashboard",')

    if new_content == content:
        print("ℹ️ No changes needed – 'chakki_dashboard' not found.")
        return True

    with open(VIEWS_FILE, 'w') as f:
        f.write(new_content)

    print("✅ Updated chakki/views.py – redirects now use 'portal_dashboard'.")
    return True

def push_changes():
    import subprocess
    response = input("\n📤 Do you want to commit and push changes to GitHub? (y/n): ").strip().lower()
    if response == 'y':
        subprocess.run("git add .", shell=True)
        subprocess.run('git commit -m "Fix: Redirect to portal_dashboard instead of missing chakki_dashboard"', shell=True)
        subprocess.run("git push origin main", shell=True)
        print("✅ Push completed. Railway will auto-deploy.")
    else:
        print("⏩ Skipping push. Please commit and push manually.")

if __name__ == "__main__":
    print("="*60)
    print("🔧 Fixing dashboard redirect in chakki/views.py")
    print("="*60)
    if fix_redirects():
        push_changes()
    else:
        print("❌ Fix failed.")
