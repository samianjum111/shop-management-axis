import subprocess
import sys
import os
import re

def run(cmd):
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    return proc.returncode, out.decode().strip(), err.decode().strip()

def extract_branch(decorations):
    """
    Given something like: (HEAD -> naya-feature, origin/naya-feature, origin/main)
    Return the best branch name (e.g., naya-feature)
    """
    if not decorations:
        return "unknown"
    
    # Remove parentheses
    clean = decorations.strip('()')
    parts = [p.strip() for p in clean.split(',')]
    
    # Priority 1: Look for 'origin/' branch (because it tells where it was pushed)
    for p in parts:
        if p.startswith('origin/'):
            return p.replace('origin/', '')
    
    # Priority 2: Look for 'HEAD -> branch' or just a branch name (without origin)
    for p in parts:
        if 'HEAD ->' in p:
            branch = p.split('->')[-1].strip()
            return branch
        # If it's a plain word and not 'HEAD', 'tag:', etc.
        if not p.startswith('HEAD') and not p.startswith('tag:') and not p.startswith('origin/'):
            # Could be local branch name
            return p
    
    # Fallback: return first part
    return parts[0]

def main():
    if not os.path.isdir('.git'):
        print("❌ Not a git repository.")
        sys.exit(1)

    # Get last 20 commits with branch decorations (%d)
    cmd = ['git', 'log', '-n', '20', '--pretty=format:%h|%d|%ad|%s', '--date=format:%Y-%m-%d %H:%M:%S']
    code, output, err = run(cmd)
    if code != 0:
        print("❌ Failed to fetch commits.")
        sys.exit(1)

    lines = output.split('\n')
    commits = []
    print("\n📜 Recent 20 Commits (Latest on top):")
    print("------------------------------------------------------------------")
    for idx, line in enumerate(lines, start=1):
        if not line:
            continue
        parts = line.split('|', 3)  # Max split 3 times
        if len(parts) < 4:
            continue
        hash_val, refs, date, title = parts[0], parts[1], parts[2], parts[3]
        
        # Extract branch name from refs
        branch = extract_branch(refs)
        
        # Cleanup branch display
        print(f"  {idx}. {hash_val} | ({branch}) | {date} | {title}")
        commits.append(hash_val)
    print("------------------------------------------------------------------")

    if not commits:
        print("❌ No commits found.")
        sys.exit(1)

    try:
        choice = input("⚡ Enter number to hard reset to (e.g., 1, 2, 3...) or 'q' to quit: ").strip()
        if choice.lower() == 'q':
            return
        num = int(choice)
        if num < 1 or num > len(commits):
            print(f"❌ Please enter a number between 1 and {len(commits)}")
            sys.exit(1)
        target_hash = commits[num-1]
    except ValueError:
        print("❌ Invalid input. Please enter a number.")
        sys.exit(1)

    print(f"⚠️  Target commit: {target_hash}")
    confirm = input("🚨 Are you sure you want to HARD RESET to this commit? This will discard ALL local changes. (y/N): ").strip().lower()
    if confirm != 'y':
        print("❌ Operation cancelled.")
        sys.exit(0)

    print(f"🔄 Resetting to {target_hash}...")
    code, out, err = run(['git', 'reset', '--hard', target_hash])
    if code != 0:
        print(f"❌ Reset failed: {err}")
        sys.exit(1)
    print(f"✅ Successfully reset to {target_hash}!")

if __name__ == "__main__":
    main()
