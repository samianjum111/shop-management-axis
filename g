#!/usr/bin/env python3
"""
Daily Expenses Patcher – safe and idempotent.
- Updates view: order_by('-expense_date', '-id'), pagination 30.
- Updates template: adds setQuickFilter JS if missing.
Run from project root: python3 patcher.py
"""

import os
import re

VIEW_PATH = "expenses/views.py"
TEMPLATE_PATH = "templates/desktop/daily_expenses.html"

def patch_view():
    with open(VIEW_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    changed = False

    # 1. Fix ordering: replace order_by('-expense_date') with order_by('-expense_date', '-id')
    # We'll look for the pattern: .order_by('-expense_date') and replace with .order_by('-expense_date', '-id')
    # But we must not duplicate -id if already present.
    pattern_order = r'(\.order_by\(\s*[\'"]-expense_date[\'"]\s*\))'
    if re.search(pattern_order, content):
        # Replace with new order_by that includes -id
        new_content = re.sub(pattern_order, r'.order_by("-expense_date", "-id")', content)
        content = new_content
        changed = True
        print("✅ Changed order_by to include '-id'.")
    else:
        print("⚠️ Could not find order_by('-expense_date') – skipping order_by fix.")

    # 2. Change Paginator per_page to 30 (currently 15)
    pattern_paginator = r'Paginator\(expenses,\s*(\d+)\)'
    if re.search(pattern_paginator, content):
        # Replace the number with 30
        new_content = re.sub(pattern_paginator, r'Paginator(expenses, 30)', content)
        content = new_content
        changed = True
        print("✅ Changed pagination to 30 per page.")
    else:
        print("⚠️ Could not find Paginator(expenses, ...) – skipping pagination fix.")

    if changed:
        with open(VIEW_PATH, "w", encoding="utf-8") as f:
            f.write(content)
        print("✅ View updated.")
    else:
        print("ℹ️ No changes needed in view.")

def patch_template():
    with open(TEMPLATE_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # Check if setQuickFilter function already exists
    if "setQuickFilter" in content:
        print("✅ Template already has setQuickFilter function.")
        return

    # Define the function to insert
    js_function = """
  // Quick filter function
  window.setQuickFilter = function(type) {
    var startDate = document.querySelector('input[name="start_date"]');
    var endDate = document.querySelector('input[name="end_date"]');
    var today = new Date();
    var y = today.getFullYear();
    var m = String(today.getMonth() + 1).padStart(2, '0');
    var d = String(today.getDate()).padStart(2, '0');
    var todayStr = y + '-' + m + '-' + d;
    var start, end;

    switch(type) {
      case 'today':
        start = end = todayStr;
        break;
      case 'week':
        var day = today.getDay();
        var diff = today.getDate() - day + (day === 0 ? -6 : 1);
        var monday = new Date(today.setDate(diff));
        var y2 = monday.getFullYear();
        var m2 = String(monday.getMonth() + 1).padStart(2, '0');
        var d2 = String(monday.getDate()).padStart(2, '0');
        start = y2 + '-' + m2 + '-' + d2;
        end = todayStr;
        break;
      case 'month':
        var firstDay = new Date(today.getFullYear(), today.getMonth(), 1);
        var y3 = firstDay.getFullYear();
        var m3 = String(firstDay.getMonth() + 1).padStart(2, '0');
        var d3 = String(firstDay.getDate()).padStart(2, '0');
        start = y3 + '-' + m3 + '-' + d3;
        end = todayStr;
        break;
      case '6months':
        var sixMonthsAgo = new Date(today);
        sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
        var y4 = sixMonthsAgo.getFullYear();
        var m4 = String(sixMonthsAgo.getMonth() + 1).padStart(2, '0');
        var d4 = String(sixMonthsAgo.getDate()).padStart(2, '0');
        start = y4 + '-' + m4 + '-' + d4;
        end = todayStr;
        break;
      case 'all':
        start = '';
        end = '';
        break;
      default: return;
    }
    startDate.value = start;
    endDate.value = end;
    document.getElementById('filterForm').submit();
  };
    """

    # Insert before the last </script> tag
    # Use DOTALL to match across lines
    pattern = r'(</script>\s*)$'
    new_content = re.sub(pattern, js_function + '\n</script>', content, flags=re.DOTALL)

    with open(TEMPLATE_PATH, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("✅ Template updated: setQuickFilter function added.")

if __name__ == "__main__":
    print("🔧 Daily Expenses Patcher")
    if not os.path.exists(VIEW_PATH):
        print(f"❌ View file not found: {VIEW_PATH}")
        exit(1)
    if not os.path.exists(TEMPLATE_PATH):
        print(f"❌ Template file not found: {TEMPLATE_PATH}")
        exit(1)

    patch_view()
    patch_template()
    print("\n🎉 Done! Restart your Django server to see the changes.")
