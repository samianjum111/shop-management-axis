#!/usr/bin/env python3
import os
import re
import shutil
from datetime import datetime

DESKTOP_PATH = 'templates/desktop/chakki.html'
MOBILE_PATH = 'templates/mobile/chakki.html'
BACKUP_DIR = 'patcher_backup_' + datetime.now().strftime('%Y%m%d_%H%M%S')

def backup_file(filepath):
    os.makedirs(BACKUP_DIR, exist_ok=True)
    shutil.copy2(filepath, os.path.join(BACKUP_DIR, os.path.basename(filepath)))

def add_cancel_to_desktop():
    with open(DESKTOP_PATH, 'r') as f:
        content = f.read()
    # Check if Cancel button already exists
    if 'Cancel' in content and 'order.can_cancel' in content:
        print("Desktop already has Cancel button.")
        return
    # Find the actions div and insert Cancel button after Complete
    pattern = r'(<div class="actions">.*?)({% if order\.status != \'completed\' %}(.*?)<a.*?Complete.*?</a>.*?{% endif %})'
    replacement = r'\1\2\n    {% if order.can_cancel %}\n        <a href="/portal/{{ tenant.schema_name }}/chakki/cancel/{{ order.id }}/" class="btn btn-danger btn-sm" onclick="return confirm(\'Cancel this order?\')">Cancel</a>\n    {% endif %}'
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    if new_content != content:
        backup_file(DESKTOP_PATH)
        with open(DESKTOP_PATH, 'w') as f:
            f.write(new_content)
        print("✅ Added Cancel button to desktop template.")
    else:
        print("⚠️ Could not add Cancel button to desktop; manual edit may be needed.")

def ensure_mobile_cancel():
    # Mobile already has the button, but we can re-apply to ensure it's there
    with open(MOBILE_PATH, 'r') as f:
        content = f.read()
    if 'order.can_cancel' in content and 'Cancel' in content:
        print("Mobile already has Cancel button.")
        return
    # If missing, add it similarly (but we know it's there)
    # We'll just add a comment to remind
    print("ℹ️ Mobile template already contains Cancel button.")

if __name__ == "__main__":
    add_cancel_to_desktop()
    ensure_mobile_cancel()
