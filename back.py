#!/usr/bin/env python3
import subprocess
import sys
import re

def run_git_command(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Error: {result.stderr}")
        sys.exit(1)
    return result.stdout.strip()

def get_commits(n=20):
    # Get commit logs: hash, date, subject
    output = run_git_command(f"git log -{n} --pretty=format:'%H|%ad|%s' --date=format:'%Y-%m-%d %H:%M:%S'")
    commits = []
    for line in output.splitlines():
        if not line:
            continue
        parts = line.split('|')
        if len(parts) >= 3:
            commits.append({
                'hash': parts[0],
                'date': parts[1],
                'subject': parts[2]
            })
    return commits

def main():
    commits = get_commits(20)
    if not commits:
        print("No commits found.")
        return

    print("\n📜 Recent commits (most recent first):")
    print("Index | Commit ID (short) | Date                | Title")
    print("-" * 70)
    for i, c in enumerate(commits, start=1):
        short_hash = c['hash'][:8]
        print(f"{i:5} | {short_hash} | {c['date']} | {c['subject']}")

    print("\nEnter the index number (1-20) or the full commit hash to reset to that commit:")
    choice = input("> ").strip()
    if not choice:
        print("❌ No input provided.")
        return

    # Determine target hash
    target_hash = None
    if choice.isdigit():
        idx = int(choice)
        if 1 <= idx <= len(commits):
            target_hash = commits[idx-1]['hash']
        else:
            print(f"❌ Index out of range (1-{len(commits)})")
            return
    else:
        # assume it's a hash (full or partial) – try to find exact match
        for c in commits:
            if c['hash'].startswith(choice):
                target_hash = c['hash']
                break
        if not target_hash:
            print("❌ No commit found with that hash prefix.")
            return

    print(f"⚠️  You are about to perform a HARD RESET to commit {target_hash[:8]}.")
    confirm = input("Are you sure? (yes/no): ").strip().lower()
    if confirm != 'yes':
        print("Aborted.")
        return

    print(f"➡️ Resetting to {target_hash[:8]}...")
    run_git_command(f"git reset --hard {target_hash}")
    print("✅ Reset successful. Your local code is now at that commit.")

if __name__ == "__main__":
    main()
