#!/usr/bin/env python3
"""
FIX: Restore the missing <div> and correct dynamic classes in mobile/chakki.html
"""

import re
from pathlib import Path

def fix_template():
    file_path = Path(__file__).parent / 'templates' / 'mobile' / 'chakki.html'
    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        return False

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # The broken line currently starts with "    class="order-card ..."
    # We need to replace it with the full <div ...> tag.
    # We'll find that exact line using a regex that matches the line starting with whitespace + "class="order-card"
    # and ends with "data-order-id="{{ order.id }}">"

    # First, let's define the correct replacement:
    correct_line = (
        '    <div class="order-card {% if order.status == \'ready\' %}order-card-ready'
        '{% elif order.payment_status == \'partial\' and order.status != \'ready\' and order.status != \'cancelled\' %}order-card-partial'
        '{% elif order.status == \'pending\' and order.payment_status == \'unpaid\' %}order-card-pending-unpaid'
        '{% elif order.status == \'completed\' and order.payment_status == \'paid\' %}order-card-completed-paid'
        '{% elif order.status == \'cancelled\' %}order-card-cancelled{% endif %}" data-order-id="{{ order.id }}">'
    )

    # Pattern to find the broken line.
    # It starts with whitespace, then "class="order-card" and includes the dynamic class logic.
    # We'll match the entire line (including the data-order-id) using a non-greedy match.
    # The line ends with "data-order-id="{{ order.id }}">" but it might have the closing > already.
    # The broken line we see in the paste is:
    #     class="order-card {% if order.status == 'ready' %}...{% endif %}" data-order-id="{{ order.id }}">
    # So we can match from "class="order-card" to the end of the line that contains data-order-id.

    pattern = r'(\s*)class="order-card {% if order\.status == \'ready\' %}.*?data-order-id="{{ order\.id }}">'

    # We'll use re.DOTALL to match across lines? Actually it's one line, so we don't need DOTALL.
    # We'll replace the entire matched group with the correct line, preserving indentation.
    def replace_match(match):
        indent = match.group(1)  # capture the leading whitespace
        return indent + correct_line.lstrip()  # correct_line already has 4 spaces, but we use indent from match

    new_content = re.sub(pattern, replace_match, content, flags=re.MULTILINE)

    if new_content == content:
        print("ℹ️  No changes needed (already fixed).")
        return True

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"✅ Fixed {file_path}")
    return True

if __name__ == "__main__":
    fix_template()	

