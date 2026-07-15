#!/usr/bin/env python3
"""
Fix IndentationError in expenses/views.py
Removes the duplicate import line inside expense_dashboard function.
Also ensures ready_orders is defined in context_processors.
Run: python3 fix_indent.py
"""
import re
from pathlib import Path

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w') as f:
        f.write(content)

def fix_expenses_indent():
    path = Path('expenses/views.py')
    if not path.exists():
        print("⚠️ expenses/views.py not found")
        return
    
    content = read_file(path)
    
    # Look for the line with extra indent and remove it
    # Pattern: lines that start with 8 spaces and contain 'from django.db.models import Sum, Q'
    # We'll remove that line entirely because the import already exists at top.
    # Use regex to find and replace.
    pattern = r'^ {8}from django\.db\.models import Sum, Q\s*$'
    new_content = re.sub(pattern, '', content, flags=re.MULTILINE)
    
    if new_content != content:
        write_file(path, new_content)
        print("✅ Removed duplicate import line with extra indent in expenses/views.py")
    else:
        print("ℹ️ No indentation error found in expenses/views.py")

def fix_context_processor():
    path = Path('core/context_processors.py')
    if not path.exists():
        print("⚠️ core/context_processors.py not found")
        return
    
    content = read_file(path)
    if 'ready_orders' not in content:
        # Insert ready_orders definition before the return statement
        lines = content.splitlines()
        new_lines = []
        for line in lines:
            if line.strip().startswith('return {'):
                new_lines.append('    ready_orders = orders.filter(status="ready").order_by("-created_at")[:10]')
            new_lines.append(line)
        new_content = '\n'.join(new_lines)
        write_file(path, new_content)
        print("✅ Added ready_orders definition in core/context_processors.py")
    else:
        print("ℹ️ core/context_processors.py already has ready_orders")

def main():
    print("🚀 Fixing indentation and missing definitions...")
    fix_expenses_indent()
    fix_context_processor()
    print("\n✅ Fixes applied.")
    print("Restart Gunicorn:")
    print("   sudo systemctl restart gunicorn")
    print("   python manage.py collectstatic --noinput")

if __name__ == "__main__":
    main()
