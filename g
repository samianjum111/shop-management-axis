#!/usr/bin/env python3
"""
Patcher: Fix Cancelled tab syntax in desktop/chakki.html
Run: python3 patcher_fix_cancelled_syntax.py
"""

import os
import re
import shutil

html_path = "templates/desktop/chakki.html"

if not os.path.exists(html_path):
    print(f"❌ File not found: {html_path}")
    exit(1)

# Backup
bak = html_path + ".bak_syntax"
shutil.copy2(html_path, bak)
print(f"✅ Backup saved: {bak}")

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

# Find the Cancelled tab line in status-tabs
# It should be something like:
# <a href="?status=cancelled{% if search_q %}&search={ search_q }{% endif %}" class="tab {% if status_filter == 'cancelled' %}active{% endif %}">Cancelled <span class="badge">{ cancelled_count }</span></a>
# We'll replace it with corrected version.

pattern = r'(<a href="\?status=cancelled\{%.*?%\}.*?class="tab.*?">Cancelled <span class="badge">\{ cancelled_count \}</span></a>)'
match = re.search(pattern, content, re.DOTALL)
if match:
    old_line = match.group(1)
    # Build corrected line
    corrected = old_line.replace('{ search_q }', '{{ search_q }}').replace('{ cancelled_count }', '{{ cancelled_count }}')
    # But also ensure the if tag is correct: the pattern above captures it, but we can just replace directly.
    # More robust: replace specific substrings.
    new_line = old_line.replace('{ search_q }', '{{ search_q }}').replace('{ cancelled_count }', '{{ cancelled_count }}')
    content = content.replace(old_line, new_line)
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("✅ Updated Cancelled tab syntax in desktop template.")
else:
    # Fallback: try to find the line with simpler pattern
    # Maybe the line is different, we can search for '{ cancelled_count }' in the line.
    lines = content.splitlines()
    for i, line in enumerate(lines):
        if '{ cancelled_count }' in line and 'Cancelled' in line:
            new_line = line.replace('{ cancelled_count }', '{{ cancelled_count }}').replace('{ search_q }', '{{ search_q }}')
            lines[i] = new_line
            with open(html_path, "w", encoding="utf-8") as f:
                f.write("\n".join(lines))
            print("✅ Updated Cancelled tab syntax (fallback method).")
            break
    else:
        print("❌ Could not find the Cancelled tab line. Manual fix required.")

print("\n✅ Done! Restart your server and refresh the page – Cancelled tab should show the correct count.")
