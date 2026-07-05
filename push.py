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
    print("📦 Pushing changes to GitHub...")
    title = input("Enter commit title: ").strip()
    if not title:
        print("❌ Commit title cannot be empty.")
        sys.exit(1)

    print("➡️ Adding all changes...")
    run_git_command("git add .")
    print("➡️ Committing...")
    run_git_command(f'git commit -m "{title}"')
    print("➡️ Pushing to origin main...")
    run_git_command("git push origin main")
    print("✅ Push successful!")

if __name__ == "__main__":
    main()
