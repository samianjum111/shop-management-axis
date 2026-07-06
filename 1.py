import subprocess
import sys
import os

def run(cmd):
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, err = proc.communicate()
    return proc.returncode, out.strip(), err.strip()

def main():
    if not os.path.isdir('.git'):
        print("❌ Not a git repository. Run this in your project root.")
        sys.exit(1)

    # 1. Check current branch
    code, cur_branch, err = run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
    if code != 0:
        print("❌ Failed to get current branch.")
        sys.exit(1)

    # 2. Cleanup Phase: Agar main nahi ho toh cleanup ka option do
    if cur_branch != "main":
        print(f"📂 Currently on branch: {cur_branch}")
        clean = input("🔄 This branch might be merged. Clean it up (checkout main, pull, delete old branch)? (y/N): ").strip().lower()
        if clean == 'y':
            print(f"🔄 Switching to main...")
            subprocess.run(['git', 'checkout', 'main'], check=False)
            print(f"⬇️ Pulling latest main from remote...")
            subprocess.run(['git', 'pull', 'origin', 'main'], check=False)
            print(f"🗑️  Deleting local branch: {cur_branch}...")
            subprocess.run(['git', 'branch', '-d', cur_branch], check=False)
            print(f"✅ Cleanup done. Local branch '{cur_branch}' deleted.")
        else:
            print("⏩ Skipping cleanup. Staying on current branch.")
            # Agar cleanup nahi karna toh wapas branch switch mat karo, but script aage badhegi.
    else:
        # Already on main, just pull latest to be safe
        print(f"📂 On main branch. Pulling latest updates...")
        subprocess.run(['git', 'pull', 'origin', 'main'], check=False)

    # 3. Naya branch name lo
    new_branch = input("🆕 Enter new feature branch name (e.g., add-payment, fix-typo): ").strip()
    if not new_branch:
        print("❌ Branch name cannot be empty.")
        sys.exit(1)
    
    if " " in new_branch:
        print("❌ Branch name cannot contain spaces. Use hyphens (-) instead.")
        sys.exit(1)

    # 4. Naya branch create karo
    print(f"🌱 Creating new branch: {new_branch}...")
    subprocess.run(['git', 'checkout', '-b', new_branch], check=False)

    # 5. SHAHZADE KE LIYE POORA RASTA (Instructions)
    print("\n" + "="*60)
    print("✅ NEW FEATURE SETUP COMPLETE!")
    print("="*60)
    print(f"📌 Current Branch: {new_branch}")
    print("\n📝 AB YE STEP-BY-STEP FOLLOW KARO:")
    print("  ─────────────────────────────────────────────")
    print(f"  1️⃣  VS Code mein apni files edit karo (changes karo).")
    print(f"  2️⃣  Terminal mein likho: python3 test.py   (commit & push karne ke liye).")
    print(f"  3️⃣  Railway Dashboard mein test service (splendid-peace) ki branch ko '{new_branch}' par set karo.")
    print(f"  4️⃣  Test URL (splendid-peace...) par jao aur apna kaam check karo.")
    print(f"  5️⃣  Agar sab theek hai, GitHub par Pull Request kholo aur MERGE karo.")
    print(f"  6️⃣  Merge ke baad, wapas terminal mein python3 1.py chalao. Ye purani branch clean up kar dega aur agle feature ke liye ready ho jayega!")
    print("="*60)

if __name__ == "__main__":
    main()
