#!/usr/bin/env python3
"""
Patcher to highlight the "Pending" KPI amount in orange.
Run: python3 highlight_pending.py
"""

import re
import os

MOBILE_FILE = 'templates/mobile/customer_profile.html'
DESKTOP_FILE = 'templates/desktop/customer_profile.html'

# ------------------------------------------------------------------
# Mobile: find the <div class="kpi-item"> where label is "Pending"
# and add style to the .number div inside it.
# ------------------------------------------------------------------
def patch_mobile():
    if not os.path.exists(MOBILE_FILE):
        print(f"⚠️  {MOBILE_FILE} not found. Skipping mobile.")
        return

    with open(MOBILE_FILE, 'r') as f:
        content = f.read()

    # Pattern: <div class="kpi-item"> ... <div class="label">Pending</div> ... </div>
    # We want to find the <div class="number"> inside that same kpi-item.
    pattern = r'(<div class="kpi-item">.*?<div class="label">Pending</div>.*?<div class="number">)([^<]*)(</div>)'
    # If style already exists, we skip.
    # We'll replace with adding style attribute if not present.

    def repl(match):
        before_number = match.group(1)
        number_text = match.group(2)
        after_number = match.group(3)
        # Check if style already present
        if 'style=' in before_number:
            # Already has style, maybe update to orange?
            # But we want to ensure it's orange. Let's just add if not present.
            # We'll add a style attribute if not present.
            if 'style="color: #e67e22;"' not in before_number:
                # Insert style before the number
                return f'{before_number} style="color: #e67e22;">{number_text}{after_number}'
            else:
                return match.group(0)
        else:
            # Insert style before the closing > of the div
            # The tag is <div class="number">, we need to insert style before >
            return f'<div class="number" style="color: #e67e22;">{number_text}{after_number}'

    new_content = re.sub(pattern, repl, content, flags=re.DOTALL)
    if new_content != content:
        with open(MOBILE_FILE, 'w') as f:
            f.write(new_content)
        print("✅ Mobile pending KPI highlighted.")
    else:
        print("ℹ️  Mobile pending KPI already highlighted or not found.")

# ------------------------------------------------------------------
# Desktop: find the <div class="stat-card"> where label is "Pending"
# and add style to the .number div inside it.
# ------------------------------------------------------------------
def patch_desktop():
    if not os.path.exists(DESKTOP_FILE):
        print(f"⚠️  {DESKTOP_FILE} not found. Skipping desktop.")
        return

    with open(DESKTOP_FILE, 'r') as f:
        content = f.read()

    # Pattern: <div class="stat-card"> ... <div class="label">Pending</div> ... </div>
    # The .number div is inside that stat-card.
    pattern = r'(<div class="stat-card">.*?<div class="label">Pending</div>.*?<div class="number">)([^<]*)(</div>)'

    def repl(match):
        before_number = match.group(1)
        number_text = match.group(2)
        after_number = match.group(3)
        if 'style="color: #e67e22;"' not in before_number:
            return f'<div class="number" style="color: #e67e22;">{number_text}{after_number}'
        else:
            return match.group(0)

    new_content = re.sub(pattern, repl, content, flags=re.DOTALL)
    if new_content != content:
        with open(DESKTOP_FILE, 'w') as f:
            f.write(new_content)
        print("✅ Desktop pending KPI highlighted.")
    else:
        print("ℹ️  Desktop pending KPI already highlighted or not found.")

if __name__ == '__main__':
    patch_mobile()
    patch_desktop()
    print("\n🎯 Done. Refresh your pages to see the orange pending amount.")
