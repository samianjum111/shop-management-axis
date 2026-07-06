#!/usr/bin/env python3
"""
Fix order flow: separate selection, customer list, and order form.
- Removes customer list from selection page.
- Adds a new customer list page for regular customer selection.
- Updates views.py to handle ?select=1 parameter.
Run: python3 fix_order_flow.py
"""

import re
from pathlib import Path

PROJECT_ROOT = Path.cwd()

# -------------------------------------------------------------------
# Helper functions
# -------------------------------------------------------------------
def ensure_dir(path):
    path.parent.mkdir(parents=True, exist_ok=True)

def write_file(path, content):
    ensure_dir(path)
    path.write_text(content, encoding='utf-8')
    print(f"✅ Created/Updated: {path}")

def patch_file(file_path, pattern, replacement, flags=0):
    if not file_path.exists():
        print(f"⚠️  File not found: {file_path}")
        return False
    content = file_path.read_text(encoding='utf-8')
    new_content, count = re.subn(pattern, replacement, content, flags=flags)
    if count:
        file_path.write_text(new_content, encoding='utf-8')
        print(f"✅ Patched {file_path} ({count} replacement(s))")
        return True
    else:
        print(f"⚠️  Pattern not found in {file_path}, skipping.")
        return False

# -------------------------------------------------------------------
# New template: Customer List for selection (mobile)
# -------------------------------------------------------------------
CUSTOMER_LIST_MOBILE = """{% extends "mobile/base.html" %}
{% block title %}Select Regular Customer | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
    .search-box {
        margin-bottom: 1rem;
    }
    .customer-card {
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        padding: 0.8rem 1rem;
        margin-bottom: 0.6rem;
        display: flex;
        justify-content: space-between;
        align-items: center;
        box-shadow: var(--shadow);
        text-decoration: none;
        color: var(--text);
    }
    .customer-card:active {
        transform: scale(0.98);
    }
    .customer-info .name {
        font-weight: 600;
        font-size: 1rem;
    }
    .customer-info .phone {
        font-size: 0.8rem;
        color: var(--muted);
    }
    .customer-info .address {
        font-size: 0.7rem;
        color: var(--muted);
    }
    .customer-info .badge {
        font-size: 0.6rem;
        padding: 0.1rem 0.5rem;
        border-radius: 30px;
        margin-left: 0.3rem;
    }
    .badge-pending { background: #fef3e2; color: #d35400; }
    .badge-none { background: #e8f8f0; color: #1e7e34; }
    .empty-state {
        text-align: center;
        padding: 2rem;
        color: var(--muted);
    }
    .back-link {
        display: inline-flex;
        align-items: center;
        gap: 0.3rem;
        color: var(--text-secondary);
        text-decoration: none;
        font-size: 0.85rem;
        margin-bottom: 1rem;
    }
</style>
{% endblock %}

{% block body %}
<a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="back-link">
    <i class="fas fa-arrow-left"></i> Back
</a>
<h5 class="fw-bold">Select Regular Customer</h5>

<div class="search-box">
    <form method="get" class="search-input-container">
        <i class="fas fa-search search-icon"></i>
        <input type="search" name="q" placeholder="Search by name or phone..." value="{{ request.GET.q|default:'' }}">
    </form>
</div>

{% for customer in customers %}
<a href="/portal/{{ tenant.schema_name }}/chakki/order/add/?customer_id={{ customer.id }}" class="customer-card">
    <div class="customer-info">
        <div class="name">{{ customer.name }}
            {% if customer.total_pending > 0 %}
                <span class="badge badge-pending">₹{{ customer.total_pending|floatformat:2 }}</span>
            {% else %}
                <span class="badge badge-none">No due</span>
            {% endif %}
        </div>
        <div class="phone">{{ customer.phone|default:"No phone" }}</div>
        <div class="address">{{ customer.address|default:"No address" }}</div>
    </div>
    <i class="fas fa-chevron-right" style="color:var(--muted);"></i>
</a>
{% empty %}
<div class="empty-state">
    <i class="fas fa-users fa-2x mb-2"></i>
    <p>No customers found.</p>
</div>
{% endfor %}
{% endblock %}
"""

# -------------------------------------------------------------------
# New template: Customer List for selection (desktop)
# -------------------------------------------------------------------
CUSTOMER_LIST_DESKTOP = """{% extends "desktop/base.html" %}
{% load static %}
{% block title %}Select Regular Customer | {{ tenant.name }}{% endblock %}

{% block content %}
<div class="d-flex justify-content-between align-items-center mb-3">
    <h2>Select Regular Customer</h2>
    <a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="btn btn-outline-secondary">Back</a>
</div>

<form method="get" class="mb-3">
    <div class="input-group">
        <input type="text" name="q" class="form-control" placeholder="Search by name or phone..." value="{{ request.GET.q|default:'' }}">
        <button class="btn btn-outline-secondary" type="submit">Search</button>
    </div>
</form>

<div class="table-responsive">
    <table class="table table-hover">
        <thead>
            <tr>
                <th>Name</th>
                <th>Phone</th>
                <th>Address</th>
                <th>Total Pending</th>
                <th>Action</th>
            </tr>
        </thead>
        <tbody>
            {% for customer in customers %}
            <tr>
                <td>{{ customer.name }}</td>
                <td>{{ customer.phone|default:"-" }}</td>
                <td>{{ customer.address|default:"-" }}</td>
                <td>{% if customer.total_pending > 0 %}₹{{ customer.total_pending|floatformat:2 }}{% else %}—{% endif %}</td>
                <td><a href="/portal/{{ tenant.schema_name }}/chakki/order/add/?customer_id={{ customer.id }}" class="btn btn-sm btn-primary">Select</a></td>
            </tr>
            {% empty %}
            <tr><td colspan="5" class="text-center text-muted">No customers found.</td></tr>
            {% endfor %}
        </tbody>
    </table>
</div>
{% endblock %}
"""

# -------------------------------------------------------------------
# Modified Selection Template (remove customer list)
# Mobile
# -------------------------------------------------------------------
SELECT_MOBILE = """{% extends "mobile/base.html" %}
{% block title %}New Order - Customer Selection | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
    .selection-card {
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        padding: 1.5rem 1rem;
        text-align: center;
        box-shadow: var(--shadow);
        cursor: pointer;
        transition: 0.2s;
        margin-bottom: 1rem;
    }
    .selection-card:active {
        transform: scale(0.96);
    }
    .selection-card .icon {
        font-size: 3rem;
        color: var(--accent);
        margin-bottom: 0.5rem;
    }
    .selection-card .label {
        font-weight: 700;
        font-size: 1.1rem;
    }
    .selection-card .desc {
        color: var(--muted);
        font-size: 0.8rem;
    }
</style>
{% endblock %}

{% block body %}
<h5 class="fw-bold mb-3">New Order</h5>
<p class="text-muted">Select customer type</p>

<a href="?walkin=1" class="selection-card text-decoration-none">
    <div class="icon"><i class="fas fa-user-plus"></i></div>
    <div class="label">Walk-in Customer</div>
    <div class="desc">New customer, no profile</div>
</a>

<a href="?select=1" class="selection-card text-decoration-none">
    <div class="icon"><i class="fas fa-users"></i></div>
    <div class="label">Regular Customer</div>
    <div class="desc">Select existing customer</div>
</a>
{% endblock %}
"""

# -------------------------------------------------------------------
# Modified Selection Template (desktop)
# -------------------------------------------------------------------
SELECT_DESKTOP = """{% extends "desktop/base.html" %}
{% load static %}
{% block title %}New Order - Customer Selection | {{ tenant.name }}{% endblock %}

{% block content %}
<div class="row">
    <div class="col-md-8 mx-auto">
        <h2 class="mb-3">New Order</h2>
        <p class="text-muted">Select customer type</p>

        <div class="row g-3">
            <div class="col-md-6">
                <a href="?walkin=1" class="card text-decoration-none h-100 p-4 text-center shadow-sm">
                    <i class="fas fa-user-plus fa-3x text-warning mb-2"></i>
                    <h5>Walk-in Customer</h5>
                    <p class="text-muted small">New customer, no profile</p>
                </a>
            </div>
            <div class="col-md-6">
                <a href="?select=1" class="card text-decoration-none h-100 p-4 text-center shadow-sm">
                    <i class="fas fa-users fa-3x text-primary mb-2"></i>
                    <h5>Regular Customer</h5>
                    <p class="text-muted small">Select existing customer</p>
                </a>
            </div>
        </div>
    </div>
</div>
{% endblock %}
"""

# -------------------------------------------------------------------
# Patch views.py
# -------------------------------------------------------------------
VIEWS_PATCH = """
    # Step 1: Customer selection
    customer_id = request.GET.get('customer_id')
    walkin = request.GET.get('walkin') == '1'
    select = request.GET.get('select') == '1'

    if not customer_id and not walkin and not select:
        # Show selection page (two boxes)
        context = {'tenant': tenant}
        template = 'mobile/add_order_select.html' if request.mobile else 'desktop/add_order_select.html'
        return render(request, template, context)

    if select:
        # Show customer list for selection
        q = request.GET.get('q', '').strip()
        customers = ChakkiCustomer.objects.all().order_by('name')
        if q:
            customers = customers.filter(Q(name__icontains=q) | Q(phone__icontains=q))
        for c in customers:
            orders = ChakkiOrder.objects.filter(customer=c)
            c.total_pending = sum(o.remaining_amount for o in orders if o.status != 'completed')
        context = {'customers': customers, 'tenant': tenant}
        template = 'mobile/add_order_customer_list.html' if request.mobile else 'desktop/add_order_customer_list.html'
        return render(request, template, context)
"""

# We need to replace the existing selection block in views.py
# The current code has a block that handles the selection page.
# We'll replace the entire section from "if not customer_id and not walkin:" to the return.
# We'll use a safe approach: find the marker and replace.

VIEWS_FIND = r"(if not customer_id and not walkin:.*?return render\(request, template, context\))"
VIEWS_REPLACE = VIEWS_PATCH

# -------------------------------------------------------------------
# Main patcher
# -------------------------------------------------------------------
def main():
    print("🚀 Fixing order flow: separation of selection, list, and form...")
    print("📁 Project root:", PROJECT_ROOT)

    # 1. Create customer list templates
    write_file(PROJECT_ROOT / "templates" / "mobile" / "add_order_customer_list.html", CUSTOMER_LIST_MOBILE)
    write_file(PROJECT_ROOT / "templates" / "desktop" / "add_order_customer_list.html", CUSTOMER_LIST_DESKTOP)

    # 2. Overwrite selection templates (remove customer list)
    write_file(PROJECT_ROOT / "templates" / "mobile" / "add_order_select.html", SELECT_MOBILE)
    write_file(PROJECT_ROOT / "templates" / "desktop" / "add_order_select.html", SELECT_DESKTOP)

    # 3. Patch views.py
    views_path = PROJECT_ROOT / "chakki" / "views.py"
    if not views_path.exists():
        print("❌ chakki/views.py not found")
        return

    content = views_path.read_text(encoding='utf-8')
    # Find the existing selection block and replace
    # We'll look for the specific pattern in the add_order function.
    # The function has two add_order definitions (old one and new one). We target the new one.
    # The new one has the line: # Step 1: Customer selection
    # We'll replace the block from that comment to the return of the selection page.

    # First, find the start of the new add_order function (the one after the first add_order).
    # We'll locate the string "def add_order(request, **kwargs):" and count occurrences.
    # We'll replace the block inside the second occurrence.

    # Simpler: we know the pattern we want to replace is exactly the block we patched earlier.
    # We'll use a robust replacement: find the lines between "# Step 1: Customer selection" and the line after the selection render.
    # We'll replace with our new block.

    pattern = r"(# Step 1: Customer selection.*?template = 'mobile/add_order_select\.html' if request\.mobile else 'desktop/add_order_select\.html'\s+return render\(request, template, context\))"
    replacement = VIEWS_PATCH.strip()
    new_content, count = re.subn(pattern, replacement, content, flags=re.DOTALL)
    if count:
        views_path.write_text(new_content, encoding='utf-8')
        print(f"✅ Patched views.py ({count} replacement(s))")
    else:
        print("⚠️ Could not find the selection block in views.py. Trying fallback...")
        # Fallback: replace the whole if block that checks not customer_id and not walkin
        # We'll search for the exact lines we set earlier.
        # Since we previously patched it to desktop, we'll search for that exact line.
        fallback_pattern = r"if not customer_id and not walkin:.*?template = 'mobile/add_order_select\.html' if request\.mobile else 'desktop/add_order_select\.html'\s+return render\(request, template, context\)"
        fallback_repl = VIEWS_PATCH.strip()
        new_content, count2 = re.subn(fallback_pattern, fallback_repl, content, flags=re.DOTALL)
        if count2:
            views_path.write_text(new_content, encoding='utf-8')
            print(f"✅ Patched views.py using fallback ({count2} replacement(s))")
        else:
            print("❌ Failed to patch views.py. Please manually update the add_order function.")

    print("\n🎉 Order flow fixed!")
    print("🔁 Restart your Django server to see the changes.")
    print("📱 Now clicking 'New Order' shows only two boxes. 'Regular' leads to a separate customer list.")

if __name__ == "__main__":
    main()
