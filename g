#!/usr/bin/env python3
"""
Replace mobile/desktop More pages with clean, premium designs.
Run once: python3 fix_more_pages.py
"""
from pathlib import Path

BASE_DIR = Path(__file__).parent

MOBILE_MORE = BASE_DIR / 'templates' / 'mobile' / 'more.html'
DESKTOP_MORE = BASE_DIR / 'templates' / 'desktop' / 'more.html'

# ----- Mobile More Page (clean, 2‑column grid, premium look) -----
MOBILE_CONTENT = '''{% extends "mobile/base.html" %}
{% block title %}More | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
  .more-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 0.8rem;
    margin-top: 0.3rem;
  }
  .more-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 1.2rem 0.5rem;
    text-align: center;
    text-decoration: none;
    color: var(--text);
    box-shadow: var(--shadow);
    transition: transform 0.15s, box-shadow 0.15s, border-color 0.2s;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.2rem;
  }
  .more-card:active {
    transform: scale(0.96);
  }
  .more-card:hover {
    border-color: var(--accent);
    box-shadow: 0 4px 16px rgba(0,0,0,0.06);
  }
  .more-card .icon {
    font-size: 2rem;
    color: var(--accent);
    line-height: 1;
  }
  .more-card .label {
    font-weight: 600;
    font-size: 0.8rem;
    color: var(--text);
  }
  .more-card .desc {
    font-size: 0.6rem;
    color: var(--muted);
  }
  .section-title {
    font-weight: 700;
    font-size: 1rem;
    margin: 1.2rem 0 0.3rem;
    color: var(--text-secondary);
    letter-spacing: -0.01em;
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .section-title .icon {
    font-size: 1.2rem;
    color: var(--accent);
  }
  .badge-count {
    background: var(--accent-light);
    color: var(--accent);
    padding: 0.1rem 0.5rem;
    border-radius: 30px;
    font-size: 0.65rem;
    font-weight: 600;
    margin-left: 0.3rem;
  }
</style>
{% endblock %}

{% block body %}
<h5 class="fw-bold mb-1">More</h5>
<p class="text-muted" style="font-size:0.8rem; margin-bottom:0.5rem;">Quick access to all sections</p>

<!-- Customers -->
<div class="section-title">
  <span class="icon"><i class="fas fa-users"></i></span> Customers
</div>
<div class="more-grid">
  <a href="/portal/{{ tenant.schema_name }}/chakki/customer/create/" class="more-card">
    <div class="icon"><i class="fas fa-user-plus"></i></div>
    <span class="label">Create Customer</span>
    <span class="desc">Add a new regular customer</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/customers/" class="more-card">
    <div class="icon"><i class="fas fa-address-book"></i></div>
    <span class="label">View Customers</span>
    <span class="desc">Manage all customers</span>
  </a>
</div>

<!-- Orders -->
<div class="section-title">
  <span class="icon"><i class="fas fa-wheat-awn"></i></span> Orders
</div>
<div class="more-grid">
  <a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="more-card">
    <div class="icon"><i class="fas fa-plus-circle"></i></div>
    <span class="label">New Order</span>
    <span class="desc">Create a new order</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/chakki/orders/pending/" class="more-card">
    <div class="icon"><i class="fas fa-clock"></i></div>
    <span class="label">Pending</span>
    <span class="desc">{{ pending_count }} pending</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/chakki/orders/ready/" class="more-card">
    <div class="icon"><i class="fas fa-hourglass-half"></i></div>
    <span class="label">Ready</span>
    <span class="desc">{{ ready_count }} ready</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/chakki/orders/completed/" class="more-card">
    <div class="icon"><i class="fas fa-check-circle"></i></div>
    <span class="label">Completed</span>
    <span class="desc">{{ completed_count }} done</span>
  </a>
</div>

<!-- Finance -->
<div class="section-title">
  <span class="icon"><i class="fas fa-coins"></i></span> Finance &amp; Expenses
</div>
<div class="more-grid">
  <a href="/portal/{{ tenant.schema_name }}/expenses/" class="more-card">
    <div class="icon"><i class="fas fa-chart-pie"></i></div>
    <span class="label">Dashboard</span>
    <span class="desc">Overview</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/expenses/daily/" class="more-card">
    <div class="icon"><i class="fas fa-receipt"></i></div>
    <span class="label">Daily Expenses</span>
    <span class="desc">Add &amp; view daily</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/expenses/loans/given/" class="more-card">
    <div class="icon"><i class="fas fa-hand-holding-usd"></i></div>
    <span class="label">Loans Given</span>
    <span class="desc">Udhaar</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/expenses/loans/taken/" class="more-card">
    <div class="icon"><i class="fas fa-hand-holding-heart"></i></div>
    <span class="label">Loans Taken</span>
    <span class="desc">Borrowed</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/expenses/reminders/" class="more-card">
    <div class="icon"><i class="fas fa-bell"></i></div>
    <span class="label">Reminders</span>
    <span class="desc">Pending</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/expenses/workers/" class="more-card">
    <div class="icon"><i class="fas fa-users"></i></div>
    <span class="label">Workers</span>
    <span class="desc">Manage staff</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/expenses/workers/attendance/" class="more-card">
    <div class="icon"><i class="fas fa-clipboard-list"></i></div>
    <span class="label">Attendance</span>
    <span class="desc">Daily attendance</span>
  </a>
  <a href="/portal/{{ tenant.schema_name }}/expenses/workers/payments/" class="more-card">
    <div class="icon"><i class="fas fa-credit-card"></i></div>
    <span class="label">Pending Payments</span>
    <span class="desc">Due salaries</span>
  </a>
</div>

<!-- Settings -->
<div class="section-title">
  <span class="icon"><i class="fas fa-cog"></i></span> Settings
</div>
<div class="more-grid">
  <a href="/portal/{{ tenant.schema_name }}/chakki/settings/" class="more-card">
    <div class="icon"><i class="fas fa-sliders-h"></i></div>
    <span class="label">Settings</span>
    <span class="desc">Rates &amp; categories</span>
  </a>
</div>
{% endblock %}
'''

# ----- Desktop More Page (3‑column grid, premium) -----
DESKTOP_CONTENT = '''{% extends "desktop/base.html" %}
{% block title %}More | {{ tenant.name }}{% endblock %}

{% block content %}
<div class="d-flex justify-content-between align-items-center mb-3">
  <h2 class="fw-bold">More</h2>
</div>
<p class="text-muted mb-4">Quick access to all portal sections</p>

<!-- Customers -->
<h5 class="fw-bold mb-3"><i class="fas fa-users text-accent me-2"></i>Customers</h5>
<div class="row g-3 mb-4">
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/chakki/customer/create/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-user-plus fa-2x text-accent mb-2"></i>
      <h6 class="fw-bold">Create Customer</h6>
      <small class="text-muted">Add a new regular customer</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/customers/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-address-book fa-2x text-accent mb-2"></i>
      <h6 class="fw-bold">View Customers</h6>
      <small class="text-muted">Manage all customers</small>
    </a>
  </div>
</div>

<!-- Orders -->
<h5 class="fw-bold mb-3"><i class="fas fa-wheat-awn text-accent me-2"></i>Orders</h5>
<div class="row g-3 mb-4">
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-plus-circle fa-2x text-accent mb-2"></i>
      <h6 class="fw-bold">New Order</h6>
      <small class="text-muted">Create a new order</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/chakki/orders/pending/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-clock fa-2x text-secondary mb-2"></i>
      <h6 class="fw-bold">Pending</h6>
      <small class="text-muted">{{ pending_count }} pending</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/chakki/orders/ready/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-hourglass-half fa-2x text-warning mb-2"></i>
      <h6 class="fw-bold">Ready</h6>
      <small class="text-muted">{{ ready_count }} ready</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/chakki/orders/completed/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-check-circle fa-2x text-success mb-2"></i>
      <h6 class="fw-bold">Completed</h6>
      <small class="text-muted">{{ completed_count }} done</small>
    </a>
  </div>
</div>

<!-- Finance -->
<h5 class="fw-bold mb-3"><i class="fas fa-coins text-accent me-2"></i>Finance &amp; Expenses</h5>
<div class="row g-3 mb-4">
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/expenses/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-chart-pie fa-2x text-primary mb-2"></i>
      <h6 class="fw-bold">Dashboard</h6>
      <small class="text-muted">Overview</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/expenses/daily/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-receipt fa-2x text-info mb-2"></i>
      <h6 class="fw-bold">Daily Expenses</h6>
      <small class="text-muted">Add &amp; view daily</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/expenses/loans/given/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-hand-holding-usd fa-2x text-success mb-2"></i>
      <h6 class="fw-bold">Loans Given</h6>
      <small class="text-muted">Udhaar</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/expenses/loans/taken/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-hand-holding-heart fa-2x text-danger mb-2"></i>
      <h6 class="fw-bold">Loans Taken</h6>
      <small class="text-muted">Borrowed</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/expenses/reminders/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-bell fa-2x text-warning mb-2"></i>
      <h6 class="fw-bold">Reminders</h6>
      <small class="text-muted">Pending</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/expenses/workers/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-users fa-2x text-primary mb-2"></i>
      <h6 class="fw-bold">Workers</h6>
      <small class="text-muted">Manage staff</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/expenses/workers/attendance/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-clipboard-list fa-2x text-secondary mb-2"></i>
      <h6 class="fw-bold">Attendance</h6>
      <small class="text-muted">Daily attendance</small>
    </a>
  </div>
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/expenses/workers/payments/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-credit-card fa-2x text-success mb-2"></i>
      <h6 class="fw-bold">Pending Payments</h6>
      <small class="text-muted">Due salaries</small>
    </a>
  </div>
</div>

<!-- Settings -->
<h5 class="fw-bold mb-3"><i class="fas fa-cog text-accent me-2"></i>Settings</h5>
<div class="row g-3 mb-4">
  <div class="col-md-3 col-6">
    <a href="/portal/{{ tenant.schema_name }}/chakki/settings/" class="card text-decoration-none h-100 p-3 text-center shadow-sm">
      <i class="fas fa-sliders-h fa-2x text-secondary mb-2"></i>
      <h6 class="fw-bold">Settings</h6>
      <small class="text-muted">Rates &amp; categories</small>
    </a>
  </div>
</div>
{% endblock %}
'''

def write_file(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated {path}")

def main():
    print("🔧 Rebuilding More pages with premium design...")
    write_file(MOBILE_MORE, MOBILE_CONTENT)
    write_file(DESKTOP_MORE, DESKTOP_CONTENT)
    print("✅ Done. Restart Django server to see the new More pages.")

if __name__ == "__main__":
    main()
