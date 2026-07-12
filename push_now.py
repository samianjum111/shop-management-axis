#!/usr/bin/env python3
import subprocess

print("🚀 Pushing changes to GitHub...")
result = subprocess.run(
    ["git", "push", "origin", "main", "--force"],
    capture_output=True,
    text=True
)

if result.returncode != 0:
    print("❌ Push failed:")
    print(result.stderr)
else:
    print("✅ Push successful!")
    print(result.stdout)
