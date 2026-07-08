#!/usr/bin/env python3
"""
Premium Customer Profile Page Patcher
- Replaces customer_profile.html with premium UI
- Adds Complete & Transcript buttons per order
Run: python3 patch_customer_profile_premium.py
"""

from pathlib import Path

FILE = Path(__file__).resolve().parent / 'templates' / 'desktop' / 'customer_profile.html'

NEW_CONTENT = """{% extends "desktop/base.html" %}
{% block title %}{{ customer.name }} | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
  /* ===== Premium Customer Profile Styles ===== */
  .page-header {
    margin-bottom: 2rem;
    padding: 0.5rem 0;
  }
  .page-header h2 {
    font-size: 2rem;
    font-weight: 700;
    color: var(--text);
    margin: 0;
    letter-spacing: -0.02em;
  }
  .page-header h2 i {
    color: var(--accent);
    margin-right: 0.4rem;
  }
  .page-header .sub {
    color: var(--muted);
    font-size: 1rem;
    margin: 0;
  }

  .profile-card {
    background: var(--surface);
    border-radius: 20px;
    border: 1px solid var(--border);
    padding: 1.5rem;
    box-shadow: 0 4px 16px rgba(0,0,0,0.04);
    margin-bottom: 1.5rem;
  }
  .profile-card .name {
    font-size: 1.6rem;
    font-weight: 700;
    color: var(--text);
    margin: 0;
  }
  .profile-card .name i {
    color: var(--accent);
    margin-right: 0.3rem;
  }
  .profile-card .phone {
    font-size: 0.95rem;
    color: var(--text-secondary);
  }
  .profile-card .phone i {
    color: var(--muted);
    margin-right: 0.3rem;
  }
  .profile-card .address {
    font-size: 0.9rem;
    color: var(--text-secondary);
    margin-top: 0.2rem;
  }
  .profile-card .address i {
    color: var(--muted);
    margin-right: 0.3rem;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    margin-bottom: 2rem;
  }
  .stat-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 1rem 0.5rem;
    text-align: center;
    box-shadow: 0 2px 8px rgba(0,0,0,0.02);
    transition: 0.25s;
  }
  .stat-card:hover {
    transform: translateY(-3px);
    box-shadow: 0 8px 24px rgba(0,0,0,0.06);
    border-color: var(--accent);
  }
  .stat-card .number {
    font-size: 1.8rem;
    font-weight: 700;
    color: var(--text);
    line-height: 1.2;
  }
  .stat-card .label {
    font-size: 0.7rem;
    text-transform: uppercase;
    color: var(--muted);
    letter-spacing: 0.04em;
    font-weight: 600;
    margin-top: 0.1rem;
  }
  .stat-card .icon {
    font-size: 1.2rem;
    margin-bottom: 0.2rem;
    display: block;
    color: var(--accent);
  }
  .stat-card.pending .icon { color: #e65100; }
  .stat-card.orders .icon { color: var(--accent); }
  .stat-card.spent .icon { color: #2e7d32; }

  .section-title {
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--text);
    margin-bottom: 1rem;
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .section-title i {
    color: var(--accent);
  }

  /* Table */
  .table-wrap {
    background: var(--surface);
    border-radius: 16px;
    border: 1px solid var(--border);
    overflow: hidden;
    box-shadow: 0 2px 12px rgba(0,0,0,0.03);
  }
  .table-wrap .table {
    margin-bottom: 0;
  }
  .table-wrap .table thead th {
    background: var(--surface-alt);
    border-bottom: 2px solid var(--border);
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 0.8rem 0.8rem;
  }
  .table-wrap .table td {
    vertical-align: middle;
    padding: 0.7rem 0.8rem;
    font-size: 0.9rem;
    border-bottom: 1px solid var(--border);
  }
  .table-wrap .table tbody tr:last-child td {
    border-bottom: none;
  }
  .table-wrap .table tbody tr:hover {
    background: var(--bg);
  }

  .badge-status {
    padding: 0.2rem 0.7rem;
    border-radius: 30px;
    font-weight: 600;
    font-size: 0.7rem;
    display: inline-block;
  }
  .badge-status.ready { background: #fef3e2; color: #d35400; }
  .badge-status.completed { background: #e8f8f0; color: #1e7e34; }
  .badge-status.pending { background: #f1f3f5; color: #495057; }
  .badge-status.partial { background: #e3f0fd; color: #2980b9; }
  .badge-status.cancelled { background: #fee2e2; color: #991b1b; }

  .btn-sm {
    border-radius: 30px;
    padding: 0.2rem 0.8rem;
    font-size: 0.7rem;
    font-weight: 600;
  }

  .empty-state {
    text-align: center;
    padding: 2rem 1rem;
    color: var(--muted);
  }
  .empty-state i {
    font-size: 2.5rem;
    color: var(--border);
    margin-bottom: 0.5rem;
    display: block;
  }

  /* Responsive */
  @media (max-width: 768px) {
    .stats-grid { grid-template-columns: 1fr 1fr; }
    .page-header h2 { font-size: 1.6rem; }
    .profile-card .name { font-size: 1.3rem; }
    .table-wrap .table thead th { font-size: 0.65rem; padding: 0.5rem; }
    .table-wrap .table td { font-size: 0.8rem; padding: 0.5rem; }
  }
  @media (max-width: 576px) {
    .stats-grid { grid-template-columns: 1fr; }
  }
</style>
{% endblock %}

{% block content %}

<!-- ===== PAGE HEADER ===== -->
<div class="page-header">
  <h2><i class="fas fa-user-circle"></i> Customer Profile</h2>
  <p class="sub">View customer details and order history</p>
</div>

<!-- ===== PROFILE CARD ===== -->
<div class="profile-card">
  <div class="name"><i class="fas fa-user"></i> {{ customer.name }}</div>
  <div class="phone"><i class="fas fa-phone"></i> {{ customer.phone|default:"No phone" }}</div>
  <div class="address"><i class="fas fa-map-marker-alt"></i> {{ customer.address|default:"No address" }}</div>
  <div class="mt-3">
    <a href="/portal/{{ tenant.schema_name }}/chakki/order/add/?customer_id={{ customer.id }}" class="btn-primary-custom" style="background:var(--accent);color:#fff;border:none;border-radius:40px;padding:0.4rem 1.4rem;font-weight:600;font-size:0.9rem;text-decoration:none;display:inline-flex;align-items:center;gap:0.4rem;box-shadow:0 4px 12px rgba(26,42,58,0.15);">
      <i class="fas fa-plus-circle"></i> New Order
    </a>
    <a href="/portal/{{ tenant.schema_name }}/customers/" class="btn-outline-custom" style="background:transparent;color:var(--text-secondary);border:1px solid var(--border);border-radius:40px;padding:0.4rem 1.2rem;font-weight:600;font-size:0.9rem;text-decoration:none;display:inline-flex;align-items:center;gap:0.4rem;margin-left:0.5rem;">
      <i class="fas fa-arrow-left"></i> Back
    </a>
  </div>
</div>

<!-- ===== STATS ===== -->
<div class="stats-grid">
  <div class="stat-card pending">
    <span class="icon"><i class="fas fa-clock"></i></span>
    <div class="number">₹{{ total_pending|floatformat:2 }}</div>
    <div class="label">Total Pending</div>
  </div>
  <div class="stat-card orders">
    <span class="icon"><i class="fas fa-shopping-cart"></i></span>
    <div class="number">{{ total_orders }}</div>
    <div class="label">Total Orders</div>
  </div>
  <div class="stat-card spent">
    <span class="icon"><i class="fas fa-rupee-sign"></i></span>
    <div class="number">₹{{ total_spent|floatformat:2 }}</div>
    <div class="label">Total Spent</div>
  </div>
</div>

<!-- ===== ORDER HISTORY ===== -->
<div class="section-title">
  <i class="fas fa-history"></i> Order History
</div>

<div class="table-wrap">
  <div class="table-responsive">
    <table class="table align-middle">
      <thead>
        <tr>
          <th>#ID</th>
          <th>Date</th>
          <th>Total</th>
          <th>Status</th>
          <th>Payment</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {% for order in orders %}
        <tr>
          <td><strong>{{ order.id }}</strong></td>
          <td>{{ order.created_at|date:"d M Y H:i" }}</td>
          <td>₹{{ order.total_amount }}</td>
          <td>
            <span class="badge-status {% if order.status == 'ready' %}ready{% elif order.status == 'completed' %}completed{% elif order.status == 'cancelled' %}cancelled{% else %}pending{% endif %}">
              {{ order.status|title }}
            </span>
          </td>
          <td>
            {% if order.payment_status == 'partial' %}
              <span class="badge-status partial">Partial</span>
            {% elif order.payment_status == 'paid' %}
              <span class="badge-status completed">Paid</span>
            {% else %}
              <span class="badge-status pending">Unpaid</span>
            {% endif %}
          </td>
          <td>
            <div class="d-flex gap-1 flex-wrap">
              <!-- Complete button (only if not completed) -->
              {% if order.status != 'completed' %}
                <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn btn-sm btn-success">
                  <i class="fas fa-check"></i> Complete
                </a>
              {% endif %}
              <!-- Transcript button (always) -->
              <a href="/portal/{{ tenant.schema_name }}/chakki/transcript/{{ order.id }}/" target="_blank" class="btn btn-sm btn-outline-secondary">
                <i class="fas fa-file-invoice"></i> Transcript
              </a>
            </div>
          </td>
        </tr>
        {% empty %}
        <tr>
          <td colspan="6">
            <div class="empty-state">
              <i class="fas fa-inbox"></i>
              <p>No orders found for this customer.</p>
            </div>
          </td>
        </tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</div>

{% endblock %}
"""

def patch():
    # Backup old file
    if FILE.exists():
        backup = FILE.with_suffix('.html.bak')
        import shutil
        shutil.copy(FILE, backup)
        print(f"✅ Backup saved: {backup}")

    with open(FILE, 'w', encoding='utf-8') as f:
        f.write(NEW_CONTENT)

    print("✅ Customer profile page updated with premium UI and action buttons.")

if __name__ == "__main__":
    if not FILE.exists():
        print(f"❌ File not found: {FILE}")
    else:
        patch()
