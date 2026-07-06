#!/usr/bin/env python3
import subprocess
import sys

def run_git_command(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Error: {result.stderr}")
        sys.exit(1)
    return result.stdout.strip()

def main():
    print("📦 Adding and pushing changes to GitHub...")
    
    # Check if there are changes
    status = run_git_command("git status --porcelain")
    if not status:
        print("✅ No changes to commit.")
        return
    
    print("➡️ Adding all changes...")
    run_git_command("git add .")
    
    # Show what's being committed
    print("\n📋 Changes to be committed:")
    print(run_git_command("git status --short"))
    
    title = input("\nEnter commit title (default: 'Fix: Tenant admin and portal login'): ").strip()
    if not title:
        title = "Fix: Tenant admin and portal login"
    
    print(f"\n➡️ Committing with message: '{title}'")
    run_git_command(f'git commit -m "{title}"')
    
    print("➡️ Pushing to origin main...")
    run_git_command("git push origin main")
    
    print("✅ Push successful!")

if __name__ == "__main__":
    main()
