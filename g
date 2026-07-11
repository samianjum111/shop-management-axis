#!/usr/bin/env python3
"""
Patcher: Remove PWA Install button from mobile and desktop base templates.
Run: python3 patcher.py
"""

import os
import re
import shutil

FILES = [
    "templates/mobile/base.html",
    "templates/desktop/base.html",
]

def remove_pwa_block(content):
    """Remove everything between <!-- ===== PWA INSTALL ... ===== --> and <!-- ===== END PWA ===== -->"""
    start_marker = "<!-- ===== PWA INSTALL (Header Button) ===== -->"
    end_marker = "<!-- ===== END PWA ===== -->"
    pattern = re.escape(start_marker) + r".*?" + re.escape(end_marker)
    new_content, n = re.subn(pattern, "", content, flags=re.DOTALL)
    return new_content, n

def process_file(filepath):
    print(f"Processing {filepath} ...")
    if not os.path.exists(filepath):
        print(f"  File not found, skipping.")
        return False

    # Backup
    backup = filepath + ".bak"
    shutil.copy2(filepath, backup)
    print(f"  Backup created: {backup}")

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    new_content, removed = remove_pwa_block(content)

    if removed == 0:
        print("  No PWA block found, nothing changed.")
        return False

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"  Removed {removed} block(s). File updated.")
    return True

def main():
    print("=== PWA Install Button Remover ===")
    for f in FILES:
        process_file(f)
    print("Done.")

if __name__ == "__main__":
    main()
