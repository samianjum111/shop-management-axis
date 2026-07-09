#!/usr/bin/env python3
"""
Full Customer Report Mega Patcher
- Adds Regular / Walk-in tabs with separate analytics
- Pagination (30 per page), search, sort, view profile
- Updates both desktop and mobile templates
"""

import os
import shutil
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent

VIEWS_FILE = PROJECT_ROOT / "reports" / "views.py"
DESKTOP_TEMPLATE = PROJECT_ROOT / "reports" / "templates" / "desktop" / "reports_customers.html"
MOBILE_TEMPLATE = PROJECT_ROOT / "reports" / "templates" / "mobile" / "reports_customers.html"

NEW_VIEWS_CUSTOMERS_FUNCTION = '''
@login_required
def customers(request, **kwargs):
    tenant = request.tenant
    customer_type = request.GET.get('type', 'regular')
    search = request.GET.get('search', '').strip()
    sort = request.GET.get('sort', 'spent')
    order = request.GET.get('order', 'desc')

    if customer_type == 'regular':
        customers_qs = ChakkiCustomer.objects.filter(tenant=tenant, is_regular=True)
    else:
        customers_qs = ChakkiCustomer.objects.filter(tenant=tenant, is_regular=False)

    customer_data = []
    for c in customers_qs:
        orders = ChakkiOrder.objects.filter(tenant=tenant, customer=c)
        completed = orders.filter(status='completed')
        total_spent = completed.aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        total_orders = orders.count()
        completed_orders = completed.count()
        avg_order = total_spent / completed_orders if completed_orders > 0 else Decimal('0')
        total_pending = Decimal('0')
        for o in orders.exclude(status='completed'):
            total_pending += o.remaining_amount
        first_order = orders.order_by('created_at').first()
        last_order = orders.order_by('-created_at').first()
        customer_data.append({
            'id': c.id,
            'name': c.name,
            'phone': c.phone or '—',
            'address': c.address or '—',
            'is_regular': c.is_regular,
            'total_spent': total_spent,
            'total_pending': total_pending,
            'total_orders': total_orders,
            'completed_orders': completed_orders,
            'avg_order': avg_order,
            'first_order': first_order.created_at if first_order else None,
            'last_order': last_order.created_at if last_order else None,
        })

    if search:
        customer_data = [c for c in customer_data if search.lower() in c['name'].lower() or search in c['phone']]

    reverse = (order == 'desc')
    if sort == 'name':
        customer_data.sort(key=lambda x: x['name'].lower(), reverse=reverse)
    elif sort == 'spent':
        customer_data.sort(key=lambda x: x['total_spent'], reverse=reverse)
    elif sort == 'orders':
        customer_data.sort(key=lambda x: x['total_orders'], reverse=reverse)
    elif sort == 'avg':
        customer_data.sort(key=lambda x: x['avg_order'], reverse=reverse)
    elif sort == 'pending':
        customer_data.sort(key=lambda x: x['total_pending'], reverse=reverse)

    from django.core.paginator import Paginator
    paginator = Paginator(customer_data, 30)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)

    total_customers = len(customer_data)
    total_revenue = sum(c['total_spent'] for c in customer_data)
    total_pending_all = sum(c['total_pending'] for c in customer_data)
    avg_customer_value = total_revenue / total_customers if total_customers else 0
    total_orders_all = sum(c['total_orders'] for c in customer_data)

    top_10 = sorted(customer_data, key=lambda x: x['total_spent'], reverse=True)[:10]
    chart_labels = [c['name'] for c in top_10]
    chart_data = [float(c['total_spent']) for c in top_10]

    context = {
        'page_obj': page_obj,
        'customer_data': page_obj.object_list,
        'total_customers': total_customers,
        'total_revenue': total_revenue,
        'total_pending_all': total_pending_all,
        'avg_customer_value': avg_customer_value,
        'total_orders_all': total_orders_all,
        'customer_type': customer_type,
        'search': search,
        'sort': sort,
        'order': order,
        'chart_labels': chart_labels,
        'chart_data': chart_data,
        'tenant': tenant,
    }
    template = 'mobile/reports_customers.html' if request.mobile else 'desktop/reports_customers.html'
    return render(request, template, context)
'''

NEW_DESKTOP_TEMPLATE = '''{% extends "desktop/base.html" %}
{% load static %}
{% block title %}Customer Analytics | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    flex-wrap: wrap;
    gap: 0.8rem;
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

  .tabs-bar {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1.5rem;
    border-bottom: 2px solid var(--border);
    padding-bottom: 0.3rem;
  }
  .tab-link {
    padding: 0.5rem 1.5rem;
    border-radius: 30px;
    font-weight: 600;
    font-size: 0.95rem;
    background: transparent;
    color: var(--text-secondary);
    border: 1px solid transparent;
    text-decoration: none;
    transition: all 0.2s;
  }
  .tab-link:hover {
    border-color: var(--border);
    color: var(--text);
  }
  .tab-link.active {
    background: var(--accent);
    color: #fff;
    border-color: var(--accent);
    box-shadow: 0 2px 12px rgba(26,42,58,0.2);
  }
  .tab-link .badge {
    margin-left: 0.4rem;
    background: rgba(0,0,0,0.08);
    color: var(--text-secondary);
    border-radius: 30px;
    padding: 0.05rem 0.5rem;
    font-weight: 600;
    font-size: 0.7rem;
  }
  .tab-link.active .badge {
    background: rgba(255,255,255,0.2);
    color: #fff;
  }

  .kpi-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 1.2rem;
    margin-bottom: 2rem;
  }
  .kpi-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 1.2rem 0.8rem;
    text-align: center;
    box-shadow: 0 4px 16px rgba(0,0,0,0.04);
    transition: 0.25s;
  }
  .kpi-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 28px rgba(0,0,0,0.07);
    border-color: var(--accent);
  }
  .kpi-card .icon {
    font-size: 1.8rem;
    color: var(--accent);
    display: block;
    margin-bottom: 0.2rem;
  }
  .kpi-card .number {
    font-size: 2rem;
    font-weight: 700;
    color: var(--text);
    line-height: 1.2;
  }
  .kpi-card .label {
    font-size: 0.7rem;
    text-transform: uppercase;
    color: var(--muted);
    letter-spacing: 0.04em;
    font-weight: 600;
  }

  .filter-bar {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 0.6rem 1.2rem;
    margin-bottom: 1.5rem;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.8rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.02);
  }
  .filter-bar .search-box {
    flex: 1;
    min-width: 180px;
    display: flex;
    align-items: center;
    gap: 0.4rem;
    background: var(--bg);
    border-radius: 40px;
    padding: 0.2rem 0.8rem;
    border: 1px solid var(--border);
    transition: 0.2s;
  }
  .filter-bar .search-box:focus-within {
    border-color: var(--accent);
    box-shadow: 0 0 0 4px rgba(26,42,58,0.06);
  }
  .filter-bar .search-box input {
    border: none;
    background: transparent;
    padding: 0.4rem 0;
    font-size: 0.9rem;
    width: 100%;
    outline: none;
    color: var(--text);
  }
  .filter-bar .search-box i {
    color: var(--muted);
  }
  .filter-bar .sort-options {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.4rem;
  }
  .filter-bar .sort-options select {
    padding: 0.3rem 1rem;
    border-radius: 40px;
    border: 1px solid var(--border);
    background: var(--surface);
    color: var(--text);
    font-size: 0.85rem;
    outline: none;
    appearance: none;
    padding-right: 2rem;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%236b7280' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 10px center;
    cursor: pointer;
  }
  .filter-bar .sort-options select:focus {
    border-color: var(--accent);
  }
  .filter-bar .btn-apply {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: 40px;
    padding: 0.3rem 1.2rem;
    font-weight: 600;
    font-size: 0.85rem;
    cursor: pointer;
    transition: 0.2s;
  }
  .filter-bar .btn-apply:hover {
    background: var(--accent-hover);
  }
  .filter-bar .btn-clear {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 40px;
    padding: 0.3rem 1rem;
    font-size: 0.85rem;
    color: var(--text-secondary);
    text-decoration: none;
    transition: 0.2s;
  }
  .filter-bar .btn-clear:hover {
    background: var(--surface-alt);
    border-color: var(--accent);
    color: var(--accent);
  }

  .chart-container {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 1rem;
    margin-bottom: 2rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.02);
  }

  .table-wrap {
    background: var(--surface);
    border-radius: 16px;
    border: 1px solid var(--border);
    overflow: hidden;
    box-shadow: 0 2px 12px rgba(0,0,0,0.03);
  }
  .table-wrap .table {
    margin-bottom: 0;
    font-size: 0.9rem;
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
    white-space: nowrap;
  }
  .table-wrap .table td {
    vertical-align: middle;
    padding: 0.7rem 0.8rem;
    border-bottom: 1px solid var(--border);
  }
  .table-wrap .table tbody tr:last-child td {
    border-bottom: none;
  }
  .table-wrap .table tbody tr:hover {
    background: var(--bg);
  }

  .badge-pending {
    background: #fef3e2;
    color: #d35400;
    padding: 0.2rem 0.7rem;
    border-radius: 30px;
    font-weight: 700;
    font-size: 0.75rem;
    display: inline-block;
  }
  .badge-none {
    background: #e8f8f0;
    color: #1e7e34;
    padding: 0.2rem 0.7rem;
    border-radius: 30px;
    font-weight: 600;
    font-size: 0.75rem;
    display: inline-block;
  }
  .customer-link {
    color: var(--accent);
    font-weight: 600;
    text-decoration: none;
  }
  .customer-link:hover {
    text-decoration: underline;
  }

  .pagination-wrap {
    display: flex;
    justify-content: center;
    margin-top: 1.5rem;
    gap: 0.3rem;
    flex-wrap: wrap;
  }
  .pagination-wrap .step-links a,
  .pagination-wrap .step-links .current,
  .pagination-wrap .step-links .disabled {
    display: inline-block;
    padding: 0.3rem 0.8rem;
    border: 1px solid var(--border);
    border-radius: 8px;
    text-decoration: none;
    color: var(--text);
    font-weight: 500;
    font-size: 0.9rem;
    transition: 0.2s;
  }
  .pagination-wrap .step-links a:hover {
    background: var(--surface-alt);
    border-color: var(--accent);
    color: var(--accent);
  }
  .pagination-wrap .step-links .current {
    background: var(--accent);
    color: #fff;
    border-color: var(--accent);
  }
  .pagination-wrap .step-links .disabled {
    color: var(--muted);
    opacity: 0.5;
    pointer-events: none;
  }

  .empty-state {
    text-align: center;
    padding: 3rem 1rem;
    color: var(--muted);
  }
  .empty-state i {
    font-size: 3rem;
    color: var(--border);
    margin-bottom: 0.5rem;
    display: block;
  }

  @media (max-width: 992px) {
    .kpi-grid { grid-template-columns: repeat(3, 1fr); }
  }
  @media (max-width: 768px) {
    .filter-bar { flex-direction: column; align-items: stretch; }
    .filter-bar .search-box { min-width: 100%; }
    .filter-bar .sort-options { justify-content: space-between; }
    .kpi-grid { grid-template-columns: 1fr 1fr; }
  }
  @media (max-width: 576px) {
    .kpi-grid { grid-template-columns: 1fr; }
  }
</style>
{% endblock %}

{% block content %}

<div class="page-header">
  <h2><i class="fas fa-users"></i> Customer Analytics</h2>
</div>

<!-- Tabs -->
<div class="tabs-bar">
  <a href="?type=regular{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}" class="tab-link {% if customer_type == 'regular' %}active{% endif %}">
    Regular <span class="badge">{{ total_customers }}</span>
  </a>
  <a href="?type=walkin{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}" class="tab-link {% if customer_type == 'walkin' %}active{% endif %}">
    Walk‑in <span class="badge">{{ total_customers }}</span>
  </a>
</div>

<!-- KPI Cards -->
<div class="kpi-grid">
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-user-friends"></i></span>
    <div class="number">{{ total_customers }}</div>
    <div class="label">Customers</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-rupee-sign"></i></span>
    <div class="number">₹{{ total_revenue|floatformat:0 }}</div>
    <div class="label">Revenue</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-hourglass-half"></i></span>
    <div class="number">₹{{ total_pending_all|floatformat:0 }}</div>
    <div class="label">Pending</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-chart-line"></i></span>
    <div class="number">₹{{ avg_customer_value|floatformat:2 }}</div>
    <div class="label">Avg Value</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-shopping-cart"></i></span>
    <div class="number">{{ total_orders_all }}</div>
    <div class="label">Total Orders</div>
  </div>
</div>

<!-- Chart -->
<div class="chart-container">
  <canvas id="customerChart" height="250"></canvas>
</div>

<!-- Filter -->
<div class="filter-bar">
  <form method="get" class="search-box">
    <i class="fas fa-search"></i>
    <input type="text" name="search" placeholder="Search by name or phone..." value="{{ search }}">
    <input type="hidden" name="type" value="{{ customer_type }}">
    <input type="hidden" name="sort" value="{{ sort }}">
    <input type="hidden" name="order" value="{{ order }}">
    <button type="submit" style="display:none;"></button>
  </form>
  <div class="sort-options">
    <select name="sort" onchange="this.form.submit()" form="filterForm">
      <option value="name" {% if sort == 'name' %}selected{% endif %}>Name</option>
      <option value="spent" {% if sort == 'spent' %}selected{% endif %}>Revenue</option>
      <option value="orders" {% if sort == 'orders' %}selected{% endif %}>Orders</option>
      <option value="avg" {% if sort == 'avg' %}selected{% endif %}>Avg Order</option>
      <option value="pending" {% if sort == 'pending' %}selected{% endif %}>Pending</option>
    </select>
    <select name="order" onchange="this.form.submit()" form="filterForm">
      <option value="asc" {% if order == 'asc' %}selected{% endif %}>Asc</option>
      <option value="desc" {% if order == 'desc' %}selected{% endif %}>Desc</option>
    </select>
    <button type="submit" class="btn-apply" form="filterForm">Apply</button>
    <a href="?type={{ customer_type }}" class="btn-clear">Clear</a>
  </div>
  <form id="filterForm" method="get" style="display:none;">
    <input type="hidden" name="type" value="{{ customer_type }}">
  </form>
</div>

<!-- Customer Table -->
<div class="table-wrap">
  <div class="table-responsive">
    <table class="table align-middle">
      <thead>
        <tr>
          <th>Customer</th>
          <th>Phone</th>
          <th>Total Orders</th>
          <th>Total Spent</th>
          <th>Avg Order</th>
          <th>Pending</th>
          <th>Last Order</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {% for c in page_obj %}
        <tr>
          <td><a href="/portal/{{ tenant.schema_name }}/chakki/customer/{{ c.id }}/" class="customer-link">{{ c.name }}</a></td>
          <td>{{ c.phone }}</td>
          <td>{{ c.total_orders }}</td>
          <td>₹{{ c.total_spent|floatformat:2 }}</td>
          <td>₹{{ c.avg_order|floatformat:2 }}</td>
          <td>
            {% if c.total_pending > 0 %}
              <span class="badge-pending">₹{{ c.total_pending|floatformat:2 }}</span>
            {% else %}
              <span class="badge-none">No due</span>
            {% endif %}
          </td>
          <td>{{ c.last_order|date:"d M Y"|default:"—" }}</td>
          <td>
            <a href="/portal/{{ tenant.schema_name }}/chakki/customer/{{ c.id }}/" class="btn btn-sm btn-outline-primary">
              <i class="fas fa-user"></i> View Profile
            </a>
          </td>
        </tr>
        {% empty %}
        <tr>
          <td colspan="8">
            <div class="empty-state">
              <i class="fas fa-users-slash"></i>
              <p>No customers found.</p>
            </div>
          </td>
        </tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</div>

<!-- Pagination -->
{% if page_obj.has_other_pages %}
<div class="pagination-wrap">
  <div class="step-links">
    {% if page_obj.has_previous %}
      <a href="?page=1&type={{ customer_type }}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">&laquo; First</a>
      <a href="?page={{ page_obj.previous_page_number }}&type={{ customer_type }}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Prev</a>
    {% else %}
      <span class="disabled">&laquo; First</span>
      <span class="disabled">Prev</span>
    {% endif %}

    <span class="current">Page {{ page_obj.number }} of {{ page_obj.paginator.num_pages }}</span>

    {% if page_obj.has_next %}
      <a href="?page={{ page_obj.next_page_number }}&type={{ customer_type }}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Next</a>
      <a href="?page={{ page_obj.paginator.num_pages }}&type={{ customer_type }}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Last &raquo;</a>
    {% else %}
      <span class="disabled">Next</span>
      <span class="disabled">Last &raquo;</span>
    {% endif %}
  </div>
</div>
{% endif %}

<script>
  document.addEventListener('DOMContentLoaded', function() {
    const ctx = document.getElementById('customerChart').getContext('2d');
    new Chart(ctx, {
      type: 'bar',
      data: {
        labels: {{ chart_labels|safe }},
        datasets: [{
          label: 'Revenue (₹)',
          data: {{ chart_data }},
          backgroundColor: 'rgba(26,42,58,0.7)',
          borderColor: 'var(--accent)',
          borderWidth: 2,
          borderRadius: 4,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'Top 10 Customers by Revenue',
            color: '#6b7280',
            font: { size: 14, weight: '600' }
          }
        },
        scales: {
          y: { beginAtZero: true, grid: { color: 'rgba(0,0,0,0.04)' } },
          x: { grid: { display: false } }
        }
      }
    });
  });
</script>

{% endblock %}
'''

NEW_MOBILE_TEMPLATE = '''{% extends "mobile/base.html" %}
{% load static %}
{% block title %}Customer Analytics | {{ tenant.name }}{% endblock %}
{% block extra_head %}
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
  .tabs-bar {
    display: flex;
    gap: 0.4rem;
    margin-bottom: 1rem;
    border-bottom: 1px solid var(--border);
    padding-bottom: 0.3rem;
  }
  .tab-link {
    flex: 1;
    text-align: center;
    padding: 0.4rem 0;
    border-radius: var(--radius);
    font-weight: 600;
    font-size: 0.8rem;
    background: transparent;
    color: var(--text-secondary);
    border: 1px solid transparent;
    text-decoration: none;
    transition: 0.2s;
  }
  .tab-link.active {
    background: var(--accent);
    color: #fff;
    border-color: var(--accent);
    box-shadow: 0 2px 8px rgba(230,126,34,0.2);
  }
  .tab-link .badge {
    margin-left: 0.2rem;
    background: rgba(0,0,0,0.08);
    border-radius: 30px;
    padding: 0.05rem 0.4rem;
    font-size: 0.6rem;
    font-weight: 600;
  }
  .tab-link.active .badge {
    background: rgba(255,255,255,0.2);
  }

  .kpi-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.6rem;
    margin-bottom: 1rem;
  }
  .kpi-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 0.8rem 0.3rem;
    text-align: center;
    box-shadow: var(--shadow);
  }
  .kpi-card .number {
    font-size: 1.2rem;
    font-weight: 700;
  }
  .kpi-card .label {
    font-size: 0.55rem;
    text-transform: uppercase;
    color: var(--muted);
    font-weight: 600;
  }

  .filter-bar {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 0.6rem;
    margin-bottom: 1rem;
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
  }
  .filter-bar .search-box {
    flex: 2;
    min-width: 100px;
    display: flex;
    align-items: center;
    gap: 0.3rem;
    background: var(--bg);
    border-radius: 30px;
    padding: 0.1rem 0.6rem;
    border: 1px solid var(--border);
  }
  .filter-bar .search-box input {
    border: none;
    background: transparent;
    padding: 0.3rem 0;
    font-size: 0.8rem;
    width: 100%;
    outline: none;
    color: var(--text);
  }
  .filter-bar select {
    padding: 0.2rem 0.5rem;
    border-radius: 30px;
    border: 1px solid var(--border);
    background: var(--surface);
    font-size: 0.7rem;
    color: var(--text);
    outline: none;
  }
  .filter-bar .btn-apply {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: 30px;
    padding: 0.2rem 0.8rem;
    font-weight: 600;
    font-size: 0.75rem;
    cursor: pointer;
  }
  .filter-bar .btn-clear {
    font-size: 0.7rem;
    color: var(--muted);
    text-decoration: none;
    padding: 0.2rem 0.4rem;
  }

  .chart-container {
    background: var(--surface);
    border-radius: var(--radius);
    padding: 0.6rem;
    border: 1px solid var(--border);
    margin-bottom: 1rem;
  }

  .customer-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 0.8rem 1rem;
    margin-bottom: 0.6rem;
    box-shadow: var(--shadow);
  }
  .customer-card .top {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .customer-card .name {
    font-weight: 700;
    font-size: 0.95rem;
    color: var(--text);
  }
  .customer-card .phone {
    font-size: 0.75rem;
    color: var(--muted);
  }
  .customer-card .stats {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.2rem;
    margin-top: 0.3rem;
    font-size: 0.7rem;
  }
  .customer-card .stats .label {
    color: var(--muted);
  }
  .customer-card .stats .value {
    font-weight: 600;
  }
  .badge-pending {
    background: #fef3e2;
    color: #d35400;
    padding: 0.1rem 0.5rem;
    border-radius: 30px;
    font-weight: 600;
    font-size: 0.65rem;
  }
  .badge-none {
    background: #e8f8f0;
    color: #1e7e34;
    padding: 0.1rem 0.5rem;
    border-radius: 30px;
    font-weight: 600;
    font-size: 0.65rem;
  }

  .empty-state {
    text-align: center;
    padding: 2rem;
    color: var(--muted);
  }
  .empty-state i {
    font-size: 2.5rem;
    display: block;
    margin-bottom: 0.3rem;
    color: var(--border);
  }

  .pagination-wrap {
    display: flex;
    justify-content: center;
    margin-top: 1rem;
    gap: 0.2rem;
    flex-wrap: wrap;
  }
  .pagination-wrap a, .pagination-wrap .current {
    padding: 0.2rem 0.6rem;
    border: 1px solid var(--border);
    border-radius: 4px;
    font-size: 0.8rem;
    text-decoration: none;
    color: var(--text);
  }
  .pagination-wrap .current {
    background: var(--accent);
    color: #fff;
    border-color: var(--accent);
  }
  .pagination-wrap .disabled {
    opacity: 0.4;
    pointer-events: none;
  }
</style>
{% endblock %}

{% block body %}
<h5 class="fw-bold">👥 Customer Analytics</h5>

<!-- Tabs -->
<div class="tabs-bar">
  <a href="?type=regular{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}" class="tab-link {% if customer_type == 'regular' %}active{% endif %}">
    Regular <span class="badge">{{ total_customers }}</span>
  </a>
  <a href="?type=walkin{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}" class="tab-link {% if customer_type == 'walkin' %}active{% endif %}">
    Walk‑in <span class="badge">{{ total_customers }}</span>
  </a>
</div>

<!-- KPI -->
<div class="kpi-grid">
  <div class="kpi-card"><div class="number">{{ total_customers }}</div><div class="label">Customers</div></div>
  <div class="kpi-card"><div class="number">₹{{ total_revenue|floatformat:0 }}</div><div class="label">Revenue</div></div>
  <div class="kpi-card"><div class="number">₹{{ total_pending_all|floatformat:0 }}</div><div class="label">Pending</div></div>
  <div class="kpi-card"><div class="number">₹{{ avg_customer_value|floatformat:2 }}</div><div class="label">Avg Value</div></div>
  <div class="kpi-card" style="grid-column: span 2;"><div class="number">{{ total_orders_all }}</div><div class="label">Total Orders</div></div>
</div>

<!-- Chart -->
<div class="chart-container"><canvas id="customerChart" height="180"></canvas></div>

<!-- Filter -->
<div class="filter-bar">
  <form method="get" class="search-box" style="flex:2;">
    <i class="fas fa-search"></i>
    <input type="text" name="search" placeholder="Search..." value="{{ search }}">
    <input type="hidden" name="type" value="{{ customer_type }}">
    <input type="hidden" name="sort" value="{{ sort }}">
    <input type="hidden" name="order" value="{{ order }}">
  </form>
  <select name="sort" onchange="this.form.submit()" form="filterFormMobile">
    <option value="name" {% if sort == 'name' %}selected{% endif %}>Name</option>
    <option value="spent" {% if sort == 'spent' %}selected{% endif %}>Revenue</option>
    <option value="orders" {% if sort == 'orders' %}selected{% endif %}>Orders</option>
    <option value="avg" {% if sort == 'avg' %}selected{% endif %}>Avg Order</option>
    <option value="pending" {% if sort == 'pending' %}selected{% endif %}>Pending</option>
  </select>
  <select name="order" onchange="this.form.submit()" form="filterFormMobile">
    <option value="asc" {% if order == 'asc' %}selected{% endif %}>↑</option>
    <option value="desc" {% if order == 'desc' %}selected{% endif %}>↓</option>
  </select>
  <button type="submit" class="btn-apply" form="filterFormMobile">Go</button>
  <a href="?type={{ customer_type }}" class="btn-clear">Clear</a>
  <form id="filterFormMobile" method="get" style="display:none;">
    <input type="hidden" name="type" value="{{ customer_type }}">
  </form>
</div>

<!-- Customer Cards -->
{% for c in page_obj %}
<div class="customer-card">
  <div class="top">
    <span class="name">{{ c.name }}</span>
    <span class="phone">{{ c.phone }}</span>
  </div>
  <div class="stats">
    <span class="label">Orders</span><span class="value">{{ c.total_orders }}</span>
    <span class="label">Revenue</span><span class="value">₹{{ c.total_spent|floatformat:2 }}</span>
    <span class="label">Avg Order</span><span class="value">₹{{ c.avg_order|floatformat:2 }}</span>
    <span class="label">Pending</span>
    <span class="value">
      {% if c.total_pending > 0 %}
        <span class="badge-pending">₹{{ c.total_pending|floatformat:2 }}</span>
      {% else %}
        <span class="badge-none">No due</span>
      {% endif %}
    </span>
  </div>
  <a href="/portal/{{ tenant.schema_name }}/chakki/customer/{{ c.id }}/" class="btn btn-sm btn-outline-primary w-100 mt-2">
    <i class="fas fa-user"></i> View Profile
  </a>
</div>
{% empty %}
<div class="empty-state"><i class="fas fa-users-slash"></i>No customers found.</div>
{% endfor %}

<!-- Pagination -->
{% if page_obj.has_other_pages %}
<div class="pagination-wrap">
  {% if page_obj.has_previous %}<a href="?page=1&type={{ customer_type }}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">&laquo;</a>{% else %}<span class="disabled">&laquo;</span>{% endif %}
  {% if page_obj.has_previous %}<a href="?page={{ page_obj.previous_page_number }}&type={{ customer_type }}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">‹</a>{% else %}<span class="disabled">‹</span>{% endif %}
  <span class="current">{{ page_obj.number }}</span>
  {% if page_obj.has_next %}<a href="?page={{ page_obj.next_page_number }}&type={{ customer_type }}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">›</a>{% else %}<span class="disabled">›</span>{% endif %}
  {% if page_obj.has_next %}<a href="?page={{ page_obj.paginator.num_pages }}&type={{ customer_type }}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">&raquo;</a>{% else %}<span class="disabled">&raquo;</span>{% endif %}
</div>
{% endif %}

<script>
  document.addEventListener('DOMContentLoaded', function() {
    const ctx = document.getElementById('customerChart').getContext('2d');
    new Chart(ctx, {
      type: 'bar',
      data: {
        labels: {{ chart_labels|safe }},
        datasets: [{
          label: 'Revenue (₹)',
          data: {{ chart_data }},
          backgroundColor: 'rgba(245,158,11,0.7)',
          borderColor: '#f59e0b',
          borderWidth: 2,
          borderRadius: 4,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          y: { beginAtZero: true, grid: { color: 'rgba(0,0,0,0.04)' } },
          x: { grid: { display: false } }
        }
      }
    });
  });
</script>
{% endblock %}
'''

def backup_file(filepath):
    if filepath.exists():
        backup = filepath.with_suffix(filepath.suffix + '.bak')
        shutil.copy2(filepath, backup)
        print(f"✅ Backup: {backup.relative_to(PROJECT_ROOT)}")
    else:
        print(f"⚠️ File not found, skipping backup: {filepath.relative_to(PROJECT_ROOT)}")

def write_file(filepath, content):
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated: {filepath.relative_to(PROJECT_ROOT)}")

def patch_views():
    if not VIEWS_FILE.exists():
        print("❌ views.py not found.")
        return
    backup_file(VIEWS_FILE)
    with open(VIEWS_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    # Replace the entire customers function
    pattern = r'(def customers\(request, \*\*kwargs\):.*?)(?=^def |\Z)'
    import re
    match = re.search(pattern, content, re.DOTALL | re.MULTILINE)
    if not match:
        print("❌ Could not find customers function. Skipping views patch.")
        return
    start = match.start()
    end = match.end()
    new_content = content[:start] + NEW_VIEWS_CUSTOMERS_FUNCTION + content[end:]
    write_file(VIEWS_FILE, new_content)

def patch_templates():
    backup_file(DESKTOP_TEMPLATE)
    write_file(DESKTOP_TEMPLATE, NEW_DESKTOP_TEMPLATE)
    backup_file(MOBILE_TEMPLATE)
    write_file(MOBILE_TEMPLATE, NEW_MOBILE_TEMPLATE)

def main():
    print("🔧 Starting Full Customer Report Mega Patcher...")
    patch_views()
    patch_templates()
    print("\n✅ All done! Now visit: http://localhost:8000/portal/j/reports/customers/")
    print("💡 Use '?type=regular' or '?type=walkin' to switch tabs (tabs are built in).")
    print("🎉 Your customer report is now fully mega-depth with regular/walk-in separation.")

if __name__ == "__main__":
    main()
