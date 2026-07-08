#!/usr/bin/env python3
"""
Fix chakki/views.py – remove duplicate import block causing SyntaxError
Run: python3 fix_views_duplicate.py
"""

import re
from pathlib import Path

VIEWS_FILE = Path(__file__).resolve().parent / 'chakki' / 'views.py'

def patch():
    with open(VIEWS_FILE, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the duplicate block: starts with '@login_required' and then a line starting with 'from django.shortcuts...'
    # We'll remove everything from that '@login_required' up to the next 'def customer_list(' (but keep the def).
    pattern = r'(@login_required\s*\nfrom django\.shortcuts import.*?)(?=\n@login_required\s*\ndef customer_list\()'
    # But the duplicate block might have more imports and function definitions. We'll use a broader approach:
    # Find the line that starts with '@login_required' and is followed by 'from django.shortcuts' on the next line.
    # Then find the next 'def customer_list(' that is also preceded by '@login_required' – that's the correct one.
    # We'll remove everything from the first pattern to just before that correct def.

    # Let's use regex to capture the duplicate block.
    # We'll search for '@login_required\nfrom django.shortcuts' and then capture until we hit the next '@login_required\ndef customer_list('
    # We'll use re.DOTALL to capture across lines.
    pattern = r'(@login_required\s*\nfrom django\.shortcuts import.*?)(?=\n@login_required\s*\ndef customer_list\()'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        # Remove the matched block
        content = content[:match.start()] + content[match.end():]
        print("✅ Removed duplicate import block.")
    else:
        print("⚠️ Duplicate block not found. Perhaps already fixed.")

    # Write back
    with open(VIEWS_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ views.py fixed.")

if __name__ == "__main__":
    patch()
