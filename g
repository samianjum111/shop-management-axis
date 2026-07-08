#!/usr/bin/env python3
"""
Fix mobile dashboard Quick Actions grid.
Run once: python3 fix_mobile_dashboard.py
"""
import re
from pathlib import Path

BASE_DIR = Path(__file__).parent
MOBILE_DASHBOARD = BASE_DIR / 'templates' / 'mobile' / 'chakki_dashboard.html'

# The new clean actions-grid with exactly 6 tiles
NEW_ACTIONS_GRID = '''
<div class="actions-grid">
    <a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="action-tile">
        <div class="icon"><i class="fas fa-plus-circle"></i></div>
        <strong>New Order</strong>
    </a>
    <a href="/portal/{{ tenant.schema_name }}/chakki/customer/create/" class="action-tile">
        <div class="icon"><i class="fas fa-user-plus"></i></div>
        <strong>Create Customer</strong>
    </a>
    <a href="/portal/{{ tenant.schema_name }}/chakki/orders/pending/" class="action-tile">
        <div class="icon"><i class="fas fa-clock"></i></div>
        <strong>Pending</strong>
    </a>
    <a href="/portal/{{ tenant.schema_name }}/chakki/orders/ready/" class="action-tile">
        <div class="icon"><i class="fas fa-hourglass-half"></i></div>
        <strong>Ready</strong>
    </a>
    <a href="/portal/{{ tenant.schema_name }}/expenses/" class="action-tile">
        <div class="icon"><i class="fas fa-money-bill-wave"></i></div>
        <strong>Expenses</strong>
    </a>
    <a href="/portal/{{ tenant.schema_name }}/chakki/settings/" class="action-tile">
        <div class="icon"><i class="fas fa-cog"></i></div>
        <strong>Settings</strong>
    </a>
</div>
'''

def main():
    if not MOBILE_DASHBOARD.exists():
        print(f"⚠️  File not found: {MOBILE_DASHBOARD}")
        return

    with open(MOBILE_DASHBOARD, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace the whole actions-grid div
    pattern = r'<div class="actions-grid">.*?</div>\s*<!-- Recent Orders -->'
    replacement = NEW_ACTIONS_GRID + '\n\n<!-- Recent Orders -->'
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

    if new_content != content:
        with open(MOBILE_DASHBOARD, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("✅ Fixed mobile dashboard – actions grid now has 6 tiles.")
    else:
        print("⚠️  Could not find the actions-grid; maybe already fixed?")

if __name__ == "__main__":
    main()
