#!/usr/bin/env python3
"""
patcher.py – Full Mega Reports Dashboard
Run with: python3 patcher.py
"""

import os
import shutil
import re

# ----------------------------------------------------------------------
# 1. NEW DASHBOARD VIEW (replaces the existing dashboard function)
# ----------------------------------------------------------------------
NEW_DASHBOARD_VIEW = '''
@login_required
def dashboard(request, **kwargs):
    from django.db.models import Sum, Count, Avg, Q
    from decimal import Decimal
    from datetime import datetime, timedelta
    from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
    from django.utils import timezone
    from chakki.models import ChakkiOrder, ChakkiOrderItem, SellingOrderItem, ChakkiCustomer

    tenant = request.tenant

    # ----- Filters -----
    start_date = request.GET.get('start_date')
    end_date = request.GET.get('end_date')
    customer_type = request.GET.get('customer_type', 'all')
    search = request.GET.get('search', '').strip()
    sort = request.GET.get('sort', 'created_at')
    order = request.GET.get('order', 'desc')
    page = request.GET.get('page', 1)

    # ----- Base queryset -----
    orders = ChakkiOrder.objects.filter(tenant=tenant)
    if customer_type == 'regular':
        orders = orders.filter(customer__is_regular=True)
    elif customer_type == 'walkin':
        orders = orders.filter(customer__is_regular=False)

    if start_date:
        try:
            start_date_obj = datetime.strptime(start_date, '%Y-%m-%d').date()
            orders = orders.filter(created_at__date__gte=start_date_obj)
        except ValueError:
            pass
    if end_date:
        try:
            end_date_obj = datetime.strptime(end_date, '%Y-%m-%d').date()
            orders = orders.filter(created_at__date__lte=end_date_obj)
        except ValueError:
            pass

    completed_orders = orders.filter(status='completed')

    # ----- KPIs -----
    total_revenue = completed_orders.aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
    total_orders = orders.count()
    total_completed = completed_orders.count()
    total_customers = orders.values('customer').distinct().count()
    avg_order_value = completed_orders.aggregate(Avg('total_amount'))['total_amount__avg'] or Decimal('0')
    total_paid = orders.aggregate(Sum('amount_paid'))['amount_paid__sum'] or Decimal('0')
    total_pending = Decimal('0')
    for o in orders.exclude(status='completed'):
        total_pending += o.remaining_amount

    # Profit (selling items only – grinding profit not calculated yet)
    total_profit = Decimal('0')
    for order in completed_orders:
        for item in order.selling_items.all():
            total_profit += item.total - (item.quantity * item.selling_price.purchase_price)

    # ----- Revenue / Orders by day (last 30 days or date range) -----
    today = timezone.now().date()
    if start_date and end_date:
        start = start_date_obj
        end = end_date_obj
        days = (end - start).days + 1
    else:
        start = today - timedelta(days=29)
        end = today
        days = 30

    revenue_by_day = {}
    orders_by_day = {}
    for i in range(days):
        day = start + timedelta(days=i)
        day_total = completed_orders.filter(created_at__date=day).aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        revenue_by_day[day.strftime('%d %b')] = float(day_total)
        orders_by_day[day.strftime('%d %b')] = orders.filter(created_at__date=day).count()

    # ----- Category revenue (top 10) -----
    cat_revenue = {}
    grinding_items = ChakkiOrderItem.objects.filter(order__in=completed_orders, tenant=tenant)
    for item in grinding_items:
        name = item.category.name
        cat_revenue[name] = cat_revenue.get(name, Decimal('0')) + item.item_total
    selling_items = SellingOrderItem.objects.filter(order__in=completed_orders, tenant=tenant)
    for item in selling_items:
        name = item.selling_price.category.name
        cat_revenue[name] = cat_revenue.get(name, Decimal('0')) + item.total
    sorted_cats = sorted(cat_revenue.items(), key=lambda x: x[1], reverse=True)[:10]
    cat_labels = [c[0] for c in sorted_cats]
    cat_data = [float(c[1]) for c in sorted_cats]

    # ----- Customer revenue (top 10) -----
    cust_revenue = {}
    for order in completed_orders:
        cid = order.customer.id
        cust_revenue[cid] = cust_revenue.get(cid, Decimal('0')) + order.total_amount
    sorted_cust = sorted(cust_revenue.items(), key=lambda x: x[1], reverse=True)[:10]
    cust_labels = []
    cust_data = []
    for cid, rev in sorted_cust:
        customer = ChakkiCustomer.objects.get(id=cid)
        cust_labels.append(customer.name)
        cust_data.append(float(rev))

    # ----- Distributions -----
    order_status_dist = {
        'Pending': orders.filter(status='pending').count(),
        'Ready': orders.filter(status='ready').count(),
        'Completed': orders.filter(status='completed').count(),
        'Cancelled': orders.filter(status='cancelled').count(),
    }
    payment_status_dist = {
        'Unpaid': orders.filter(payment_status='unpaid').count(),
        'Partial': orders.filter(payment_status='partial').count(),
        'Paid': orders.filter(payment_status='paid').count(),
    }

    # ----- Orders table with search, sorting, pagination -----
    if search:
        orders = orders.filter(
            Q(customer__name__icontains=search) |
            Q(customer__phone__icontains=search) |
            Q(id__icontains=search)
        )
    # Sorting
    sort_field = 'created_at'
    if sort == 'id':
        sort_field = 'id'
    elif sort == 'customer':
        sort_field = 'customer__name'
    elif sort == 'total':
        sort_field = 'total_amount'
    elif sort == 'paid':
        sort_field = 'amount_paid'
    elif sort == 'status':
        sort_field = 'status'
    elif sort == 'payment_status':
        sort_field = 'payment_status'
    elif sort == 'remaining':
        orders_list = list(orders)
        orders_list.sort(key=lambda o: o.remaining_amount, reverse=(order == 'desc'))
        orders = orders_list

    if sort_field != 'remaining' and sort_field != 'created_at':
        if order == 'desc':
            sort_field = '-' + sort_field
        orders = orders.order_by(sort_field)
    elif sort_field == 'created_at':
        if order == 'desc':
            orders = orders.order_by('-created_at')
        else:
            orders = orders.order_by('created_at')

    paginator = Paginator(orders, 30)
    try:
        page_obj = paginator.page(page)
    except (EmptyPage, PageNotAnInteger):
        page_obj = paginator.page(1)

    # ----- Chart labels/data -----
    revenue_labels = list(revenue_by_day.keys())
    revenue_data = list(revenue_by_day.values())
    orders_labels = list(orders_by_day.keys())
    orders_data = list(orders_by_day.values())
    payment_labels = list(payment_status_dist.keys())
    payment_data = list(payment_status_dist.values())
    order_labels = list(order_status_dist.keys())
    order_data = list(order_status_dist.values())

    context = {
        'total_revenue': total_revenue,
        'total_orders': total_orders,
        'total_completed': total_completed,
        'total_customers': total_customers,
        'avg_order_value': avg_order_value,
        'total_paid': total_paid,
        'total_pending': total_pending,
        'total_profit': total_profit,
        'revenue_labels': revenue_labels,
        'revenue_data': revenue_data,
        'orders_labels': orders_labels,
        'orders_data': orders_data,
        'cat_labels': cat_labels,
        'cat_data': cat_data,
        'cust_labels': cust_labels,
        'cust_data': cust_data,
        'payment_labels': payment_labels,
        'payment_data': payment_data,
        'order_labels': order_labels,
        'order_data': order_data,
        'page_obj': page_obj,
        'start_date': start_date,
        'end_date': end_date,
        'customer_type': customer_type,
        'search': search,
        'sort': sort,
        'order': order,
        'tenant': tenant,
    }
    template = 'mobile/reports_dashboard.html' if request.mobile else 'desktop/reports_dashboard.html'
    return render(request, template, context)
'''

# ----------------------------------------------------------------------
# 2. NEW DESKTOP TEMPLATE
# ----------------------------------------------------------------------
NEW_DESKTOP_TEMPLATE = '''{% extends "desktop/base.html" %}
{% load static %}
{% block title %}Reports Dashboard | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
  .page-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:2rem; flex-wrap:wrap; gap:0.8rem; }
  .page-header h2 { font-size:2rem; font-weight:700; color:var(--text); margin:0; letter-spacing:-0.02em; }
  .page-header h2 i { color:var(--accent); margin-right:0.5rem; }

  .stats-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:1.2rem; margin-bottom:2rem; }
  .stat-card { background:var(--surface); border:1px solid var(--border); border-radius:16px; padding:1rem 0.6rem; text-align:center; box-shadow:var(--shadow); transition:0.25s; }
  .stat-card:hover { transform:translateY(-4px); box-shadow:var(--hover-shadow); border-color:var(--accent); }
  .stat-card .number { font-size:1.8rem; font-weight:700; color:var(--text); line-height:1.2; }
  .stat-card .label { font-size:0.7rem; text-transform:uppercase; color:var(--muted); letter-spacing:0.04em; font-weight:600; margin-top:0.1rem; }
  .stat-card .icon { font-size:1.4rem; color:var(--accent); margin-bottom:0.2rem; display:block; }

  .filter-bar { background:var(--surface); border:1px solid var(--border); border-radius:20px; padding:1rem 1.5rem; margin-bottom:2rem; display:flex; flex-wrap:wrap; align-items:flex-end; gap:1rem; box-shadow:var(--shadow); }
  .filter-bar .form-group { flex:1 1 160px; min-width:120px; }
  .filter-bar .form-group label { display:block; font-weight:600; font-size:0.75rem; text-transform:uppercase; color:var(--muted); letter-spacing:0.04em; margin-bottom:0.2rem; }
  .filter-bar .form-control, .filter-bar .form-select { border-radius:40px; border:1.5px solid var(--border); padding:0.4rem 1rem; font-size:0.9rem; background:var(--bg); color:var(--text); transition:0.2s; width:100%; }
  .filter-bar .form-control:focus, .filter-bar .form-select:focus { border-color:var(--accent); box-shadow:0 0 0 4px rgba(26,42,58,0.06); outline:none; }
  .filter-bar .btn-apply { background:var(--accent); color:#fff; border:none; border-radius:40px; padding:0.4rem 1.6rem; font-weight:600; font-size:0.9rem; cursor:pointer; transition:0.2s; box-shadow:0 4px 12px rgba(26,42,58,0.15); flex:0 0 auto; }
  .filter-bar .btn-apply:hover { background:var(--accent-hover); transform:translateY(-2px); box-shadow:0 8px 24px rgba(26,42,58,0.2); }
  .filter-bar .btn-clear { background:transparent; border:1px solid var(--border); border-radius:40px; padding:0.4rem 1.2rem; font-weight:600; font-size:0.9rem; color:var(--text-secondary); text-decoration:none; transition:0.2s; flex:0 0 auto; }
  .filter-bar .btn-clear:hover { background:var(--surface-alt); border-color:var(--accent); color:var(--accent); }

  .charts-grid { display:grid; grid-template-columns:1fr 1fr; gap:1.5rem; margin-bottom:2rem; }
  .chart-box { background:var(--surface); border:1px solid var(--border); border-radius:20px; padding:1rem 1rem 0.5rem; box-shadow:var(--shadow); transition:0.25s; }
  .chart-box:hover { box-shadow:var(--hover-shadow); }
  .chart-box .chart-title { font-weight:600; font-size:0.85rem; color:var(--text-secondary); margin-bottom:0.3rem; }
  .chart-box canvas { max-height:200px; width:100% !important; }
  .chart-box.full-width { grid-column:1 / -1; }
  .chart-box.full-width canvas { max-height:220px; }

  .table-container { background:var(--surface); border:1px solid var(--border); border-radius:20px; padding:0.5rem 0; box-shadow:var(--shadow); overflow-x:auto; }
  .table-premium { width:100%; border-collapse:separate; border-spacing:0; font-size:0.9rem; min-width:800px; }
  .table-premium thead th { background:var(--surface-alt); color:var(--text-secondary); font-weight:600; font-size:0.75rem; text-transform:uppercase; letter-spacing:0.04em; padding:0.8rem 1rem; border-bottom:1px solid var(--border); position:sticky; top:0; z-index:2; }
  .table-premium tbody td { padding:0.7rem 1rem; border-bottom:1px solid var(--border); color:var(--text); vertical-align:middle; }
  .table-premium tbody tr:last-child td { border-bottom:none; }
  .table-premium tbody tr:hover td { background:var(--bg); }
  .table-premium .order-id { font-weight:600; color:var(--accent); }
  .table-premium .amount { font-weight:600; white-space:nowrap; }

  .badge-premium { display:inline-block; padding:0.2rem 0.7rem; border-radius:40px; font-weight:600; font-size:0.7rem; text-transform:capitalize; }
  .badge-ready { background:#fff3cd; color:#856404; }
  .badge-completed { background:#d4edda; color:#155724; }
  .badge-pending { background:#e2e3e5; color:#383d41; }
  .badge-cancelled { background:#f8d7da; color:#b02a37; }
  .badge-paid { background:#d4edda; color:#155724; }
  .badge-partial { background:#d1ecf1; color:#0c5460; }
  .badge-unpaid { background:#f8d7da; color:#b02a37; }

  .pagination-wrap { display:flex; justify-content:center; margin-top:1.5rem; gap:0.3rem; flex-wrap:wrap; }
  .pagination-wrap .step-links a, .pagination-wrap .step-links .current, .pagination-wrap .step-links .disabled { display:inline-block; padding:0.3rem 0.8rem; border:1px solid var(--border); border-radius:8px; text-decoration:none; color:var(--text); font-weight:500; font-size:0.9rem; transition:0.2s; }
  .pagination-wrap .step-links a:hover { background:var(--surface-alt); border-color:var(--accent); color:var(--accent); }
  .pagination-wrap .step-links .current { background:var(--accent); color:#fff; border-color:var(--accent); }
  .pagination-wrap .step-links .disabled { color:var(--muted); opacity:0.5; pointer-events:none; }

  .empty-state { text-align:center; padding:2rem 1rem; color:var(--muted); }
  .empty-state i { font-size:2.5rem; color:var(--border); margin-bottom:0.5rem; display:block; }

  @media (max-width:992px) { .stats-grid { grid-template-columns:repeat(2,1fr); } .charts-grid { grid-template-columns:1fr; } .filter-bar .form-group { flex:1 1 100%; } }
  @media (max-width:768px) { .page-header { flex-direction:column; align-items:stretch; } .stats-grid { grid-template-columns:1fr 1fr; } }
  @media (max-width:576px) { .stats-grid { grid-template-columns:1fr; } }
</style>
{% endblock %}

{% block content %}
<div class="page-header">
  <h2><i class="fas fa-chart-pie"></i> Reports Dashboard</h2>
</div>

<!-- ===== STATS ===== -->
<div class="stats-grid">
  <div class="stat-card"><span class="icon"><i class="fas fa-coins"></i></span><div class="number">₹{{ total_revenue|floatformat:0 }}</div><div class="label">Revenue</div></div>
  <div class="stat-card"><span class="icon"><i class="fas fa-shopping-cart"></i></span><div class="number">{{ total_orders }}</div><div class="label">Orders</div></div>
  <div class="stat-card"><span class="icon"><i class="fas fa-check-circle"></i></span><div class="number">{{ total_completed }}</div><div class="label">Completed</div></div>
  <div class="stat-card"><span class="icon"><i class="fas fa-users"></i></span><div class="number">{{ total_customers }}</div><div class="label">Customers</div></div>
  <div class="stat-card"><span class="icon"><i class="fas fa-chart-line"></i></span><div class="number">₹{{ avg_order_value|floatformat:2 }}</div><div class="label">Avg Order</div></div>
  <div class="stat-card"><span class="icon"><i class="fas fa-credit-card"></i></span><div class="number">₹{{ total_paid|floatformat:0 }}</div><div class="label">Paid</div></div>
  <div class="stat-card"><span class="icon"><i class="fas fa-hourglass-half"></i></span><div class="number">₹{{ total_pending|floatformat:0 }}</div><div class="label">Pending</div></div>
  <div class="stat-card"><span class="icon"><i class="fas fa-chart-pie"></i></span><div class="number">₹{{ total_profit|floatformat:0 }}</div><div class="label">Profit</div></div>
</div>

<!-- ===== FILTER BAR ===== -->
<form method="get" class="filter-bar">
  <div class="form-group">
    <label>From</label>
    <input type="date" name="start_date" class="form-control" value="{{ start_date|default:'' }}">
  </div>
  <div class="form-group">
    <label>To</label>
    <input type="date" name="end_date" class="form-control" value="{{ end_date|default:'' }}">
  </div>
  <div class="form-group">
    <label>Customer Type</label>
    <select name="customer_type" class="form-select">
      <option value="all" {% if customer_type == 'all' %}selected{% endif %}>All</option>
      <option value="regular" {% if customer_type == 'regular' %}selected{% endif %}>Regular</option>
      <option value="walkin" {% if customer_type == 'walkin' %}selected{% endif %}>Walk‑in</option>
    </select>
  </div>
  <div class="form-group" style="flex:2;">
    <label>Search</label>
    <input type="text" name="search" class="form-control" placeholder="Customer, phone, order ID..." value="{{ search|default:'' }}">
  </div>
  <button type="submit" class="btn-apply"><i class="fas fa-filter"></i> Apply</button>
  <a href="?" class="btn-clear"><i class="fas fa-times"></i> Clear</a>
</form>

<!-- ===== CHARTS ===== -->
<div class="charts-grid">
  <div class="chart-box">
    <div class="chart-title"><i class="fas fa-chart-line"></i> Revenue Trend</div>
    <canvas id="revenueChart"></canvas>
  </div>
  <div class="chart-box">
    <div class="chart-title"><i class="fas fa-chart-bar"></i> Orders Trend</div>
    <canvas id="ordersChart"></canvas>
  </div>
  <div class="chart-box">
    <div class="chart-title"><i class="fas fa-doughnut-chart"></i> Order Status</div>
    <canvas id="statusChart"></canvas>
  </div>
  <div class="chart-box">
    <div class="chart-title"><i class="fas fa-doughnut-chart"></i> Payment Status</div>
    <canvas id="paymentChart"></canvas>
  </div>
  <div class="chart-box full-width">
    <div class="chart-title"><i class="fas fa-tags"></i> Top Categories by Revenue</div>
    <canvas id="categoryChart"></canvas>
  </div>
  <div class="chart-box full-width">
    <div class="chart-title"><i class="fas fa-users"></i> Top Customers by Revenue</div>
    <canvas id="customerChart"></canvas>
  </div>
</div>

<!-- ===== ORDERS TABLE ===== -->
<div class="table-container">
  <table class="table-premium">
    <thead>
      <tr>
        <th><a href="?sort=id&order={% if sort == 'id' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">ID</a></th>
        <th><a href="?sort=customer&order={% if sort == 'customer' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Customer</a></th>
        <th>Phone</th>
        <th><a href="?sort=total&order={% if sort == 'total' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Total</a></th>
        <th><a href="?sort=paid&order={% if sort == 'paid' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Paid</a></th>
        <th><a href="?sort=remaining&order={% if sort == 'remaining' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Remaining</a></th>
        <th><a href="?sort=status&order={% if sort == 'status' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Status</a></th>
        <th><a href="?sort=payment_status&order={% if sort == 'payment_status' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Payment</a></th>
        <th>Date</th>
        <th>Action</th>
      </tr>
    </thead>
    <tbody>
      {% for order in page_obj %}
      <tr>
        <td class="order-id">#{{ order.id }}</td>
        <td>{{ order.customer.name }}</td>
        <td>{{ order.customer.phone|default:"—" }}</td>
        <td class="amount">₹{{ order.total_amount|floatformat:2 }}</td>
        <td class="amount">₹{{ order.amount_paid|floatformat:2 }}</td>
        <td class="amount">₹{{ order.remaining_amount|floatformat:2 }}</td>
        <td>
          <span class="badge-premium
            {% if order.status == 'ready' %}badge-ready
            {% elif order.status == 'completed' %}badge-completed
            {% elif order.status == 'cancelled' %}badge-cancelled
            {% else %}badge-pending{% endif %}">
            {{ order.status|title }}
          </span>
        </td>
        <td>
          <span class="badge-premium
            {% if order.payment_status == 'paid' %}badge-paid
            {% elif order.payment_status == 'partial' %}badge-partial
            {% else %}badge-unpaid{% endif %}">
            {{ order.payment_status|title }}
          </span>
        </td>
        <td>{{ order.created_at|date:"d M Y H:i" }}</td>
        <td>
          <a href="/portal/{{ tenant.schema_name }}/chakki/order/{{ order.id }}/" class="btn btn-sm btn-outline-primary">View</a>
        </td>
      </tr>
      {% empty %}
      <tr>
        <td colspan="10">
          <div class="empty-state">
            <i class="fas fa-inbox"></i>
            <p>No orders match your filters.</p>
          </div>
        </td>
      </tr>
      {% endfor %}
    </tbody>
  </table>
</div>

<!-- ===== PAGINATION ===== -->
{% if page_obj.has_other_pages %}
<div class="pagination-wrap">
  <div class="step-links">
    {% if page_obj.has_previous %}
      <a href="?page=1{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">&laquo; First</a>
      <a href="?page={{ page_obj.previous_page_number }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Prev</a>
    {% else %}
      <span class="disabled">&laquo; First</span>
      <span class="disabled">Prev</span>
    {% endif %}

    <span class="current">Page {{ page_obj.number }} of {{ page_obj.paginator.num_pages }}</span>

    {% if page_obj.has_next %}
      <a href="?page={{ page_obj.next_page_number }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Next</a>
      <a href="?page={{ page_obj.paginator.num_pages }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Last &raquo;</a>
    {% else %}
      <span class="disabled">Next</span>
      <span class="disabled">Last &raquo;</span>
    {% endif %}
  </div>
</div>
{% endif %}

<script>
  document.addEventListener('DOMContentLoaded', function() {
    // Revenue Chart
    new Chart(document.getElementById('revenueChart'), {
      type: 'line',
      data: {
        labels: {{ revenue_labels|safe }},
        datasets: [{ label: 'Revenue (₹)', data: {{ revenue_data }}, borderColor: '#e67e22', backgroundColor: 'rgba(230,126,34,0.1)', tension: 0.2, fill: true }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
    });

    // Orders Chart
    new Chart(document.getElementById('ordersChart'), {
      type: 'bar',
      data: {
        labels: {{ orders_labels|safe }},
        datasets: [{ label: 'Orders', data: {{ orders_data }}, backgroundColor: 'rgba(26,42,58,0.6)', borderColor: 'var(--accent)', borderWidth: 1 }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, stepSize: 1 } } }
    });

    // Status Chart
    new Chart(document.getElementById('statusChart'), {
      type: 'doughnut',
      data: {
        labels: {{ order_labels|safe }},
        datasets: [{ data: {{ order_data }}, backgroundColor: ['#f1c40f', '#3498db', '#2ecc71', '#e74c3c'] }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }
    });

    // Payment Chart
    new Chart(document.getElementById('paymentChart'), {
      type: 'doughnut',
      data: {
        labels: {{ payment_labels|safe }},
        datasets: [{ data: {{ payment_data }}, backgroundColor: ['#e74c3c', '#f39c12', '#2ecc71'] }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }
    });

    // Category Chart
    new Chart(document.getElementById('categoryChart'), {
      type: 'bar',
      data: {
        labels: {{ cat_labels|safe }},
        datasets: [{ label: 'Revenue (₹)', data: {{ cat_data }}, backgroundColor: ['#3498db','#e67e22','#2ecc71','#9b59b6','#f1c40f','#1abc9c','#e74c3c','#34495e','#95a5a6','#f39c12'], borderColor: '#fff', borderWidth: 2 }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
    });

    // Customer Chart
    new Chart(document.getElementById('customerChart'), {
      type: 'bar',
      data: {
        labels: {{ cust_labels|safe }},
        datasets: [{ label: 'Revenue (₹)', data: {{ cust_data }}, backgroundColor: 'rgba(26,42,58,0.7)', borderColor: 'var(--accent)', borderWidth: 2 }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
    });
  });
</script>
{% endblock %}
'''

# ----------------------------------------------------------------------
# 3. NEW MOBILE TEMPLATE (adapted for small screens)
# ----------------------------------------------------------------------
NEW_MOBILE_TEMPLATE = '''{% extends "mobile/base.html" %}
{% load static %}
{% block title %}Reports Dashboard | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
  .stats-grid { display:grid; grid-template-columns:1fr 1fr; gap:0.6rem; margin-bottom:1.2rem; }
  .stat-card { background:var(--surface); border:1px solid var(--border); border-radius:var(--radius); padding:0.6rem 0.3rem; text-align:center; box-shadow:var(--shadow); }
  .stat-card .number { font-size:1.2rem; font-weight:700; color:var(--text); }
  .stat-card .label { font-size:0.55rem; text-transform:uppercase; color:var(--muted); letter-spacing:0.04em; font-weight:600; }

  .filter-bar { background:var(--surface); border:1px solid var(--border); border-radius:var(--radius); padding:0.6rem; margin-bottom:1rem; display:flex; flex-wrap:wrap; gap:0.4rem; }
  .filter-bar .form-group { flex:1 1 100%; min-width:0; }
  .filter-bar .form-group label { display:block; font-weight:600; font-size:0.65rem; text-transform:uppercase; color:var(--muted); margin-bottom:0.1rem; }
  .filter-bar .form-control, .filter-bar .form-select { border-radius:30px; border:1px solid var(--border); padding:0.3rem 0.6rem; font-size:0.8rem; background:var(--bg); color:var(--text); width:100%; }
  .filter-bar .btn-apply { background:var(--accent); color:#fff; border:none; border-radius:30px; padding:0.3rem 1rem; font-weight:600; font-size:0.8rem; cursor:pointer; transition:0.2s; flex:1; }
  .filter-bar .btn-clear { background:transparent; border:1px solid var(--border); border-radius:30px; padding:0.3rem 0.8rem; font-weight:600; font-size:0.8rem; color:var(--text-secondary); text-decoration:none; flex:1; text-align:center; }

  .charts-grid { display:grid; grid-template-columns:1fr; gap:1rem; margin-bottom:1.2rem; }
  .chart-box { background:var(--surface); border:1px solid var(--border); border-radius:var(--radius); padding:0.6rem; }
  .chart-box .chart-title { font-weight:600; font-size:0.7rem; color:var(--text-secondary); margin-bottom:0.2rem; }
  .chart-box canvas { max-height:160px; width:100% !important; }

  .table-container { background:var(--surface); border:1px solid var(--border); border-radius:var(--radius); overflow-x:auto; padding:0.2rem 0; }
  .table-premium { width:100%; border-collapse:collapse; font-size:0.7rem; min-width:600px; }
  .table-premium thead th { background:var(--surface-alt); color:var(--text-secondary); font-weight:600; font-size:0.6rem; text-transform:uppercase; padding:0.4rem 0.4rem; border-bottom:1px solid var(--border); }
  .table-premium tbody td { padding:0.4rem 0.4rem; border-bottom:1px solid var(--border); color:var(--text); vertical-align:middle; }
  .table-premium tbody tr:last-child td { border-bottom:none; }
  .table-premium .order-id { font-weight:600; color:var(--accent); }
  .table-premium .amount { font-weight:600; white-space:nowrap; }

  .badge-premium { display:inline-block; padding:0.1rem 0.5rem; border-radius:30px; font-weight:600; font-size:0.6rem; text-transform:capitalize; }
  .badge-ready { background:#fff3cd; color:#856404; }
  .badge-completed { background:#d4edda; color:#155724; }
  .badge-pending { background:#e2e3e5; color:#383d41; }
  .badge-cancelled { background:#f8d7da; color:#b02a37; }
  .badge-paid { background:#d4edda; color:#155724; }
  .badge-partial { background:#d1ecf1; color:#0c5460; }
  .badge-unpaid { background:#f8d7da; color:#b02a37; }

  .pagination-wrap { display:flex; justify-content:center; margin-top:1rem; gap:0.2rem; flex-wrap:wrap; }
  .pagination-wrap .step-links a, .pagination-wrap .step-links .current, .pagination-wrap .step-links .disabled { display:inline-block; padding:0.2rem 0.6rem; border:1px solid var(--border); border-radius:4px; text-decoration:none; color:var(--text); font-weight:500; font-size:0.75rem; }
  .pagination-wrap .step-links a:hover { background:var(--surface-alt); border-color:var(--accent); color:var(--accent); }
  .pagination-wrap .step-links .current { background:var(--accent); color:#fff; border-color:var(--accent); }
  .pagination-wrap .step-links .disabled { color:var(--muted); opacity:0.5; pointer-events:none; }

  .empty-state { text-align:center; padding:1rem; color:var(--muted); }
  .empty-state i { font-size:1.5rem; color:var(--border); margin-bottom:0.2rem; display:block; }

  @media (max-width:400px) { .stats-grid { grid-template-columns:1fr 1fr; } .table-premium { font-size:0.6rem; } }
</style>
{% endblock %}

{% block body %}
<h5 class="fw-bold mb-2">📊 Reports Dashboard</h5>

<!-- ===== STATS ===== -->
<div class="stats-grid">
  <div class="stat-card"><div class="number">₹{{ total_revenue|floatformat:0 }}</div><div class="label">Revenue</div></div>
  <div class="stat-card"><div class="number">{{ total_orders }}</div><div class="label">Orders</div></div>
  <div class="stat-card"><div class="number">{{ total_completed }}</div><div class="label">Completed</div></div>
  <div class="stat-card"><div class="number">{{ total_customers }}</div><div class="label">Customers</div></div>
  <div class="stat-card"><div class="number">₹{{ avg_order_value|floatformat:2 }}</div><div class="label">Avg Order</div></div>
  <div class="stat-card"><div class="number">₹{{ total_paid|floatformat:0 }}</div><div class="label">Paid</div></div>
  <div class="stat-card"><div class="number">₹{{ total_pending|floatformat:0 }}</div><div class="label">Pending</div></div>
  <div class="stat-card"><div class="number">₹{{ total_profit|floatformat:0 }}</div><div class="label">Profit</div></div>
</div>

<!-- ===== FILTER ===== -->
<form method="get" class="filter-bar">
  <div class="form-group"><label>From</label><input type="date" name="start_date" class="form-control" value="{{ start_date|default:'' }}"></div>
  <div class="form-group"><label>To</label><input type="date" name="end_date" class="form-control" value="{{ end_date|default:'' }}"></div>
  <div class="form-group"><label>Customer</label>
    <select name="customer_type" class="form-select">
      <option value="all" {% if customer_type == 'all' %}selected{% endif %}>All</option>
      <option value="regular" {% if customer_type == 'regular' %}selected{% endif %}>Regular</option>
      <option value="walkin" {% if customer_type == 'walkin' %}selected{% endif %}>Walk‑in</option>
    </select>
  </div>
  <div class="form-group"><label>Search</label><input type="text" name="search" class="form-control" placeholder="Search..." value="{{ search|default:'' }}"></div>
  <button type="submit" class="btn-apply">Apply</button>
  <a href="?" class="btn-clear">Clear</a>
</form>

<!-- ===== CHARTS ===== -->
<div class="charts-grid">
  <div class="chart-box"><div class="chart-title">Revenue Trend</div><canvas id="revenueChart"></canvas></div>
  <div class="chart-box"><div class="chart-title">Orders Trend</div><canvas id="ordersChart"></canvas></div>
  <div class="chart-box"><div class="chart-title">Order Status</div><canvas id="statusChart"></canvas></div>
  <div class="chart-box"><div class="chart-title">Payment Status</div><canvas id="paymentChart"></canvas></div>
  <div class="chart-box"><div class="chart-title">Top Categories</div><canvas id="categoryChart"></canvas></div>
  <div class="chart-box"><div class="chart-title">Top Customers</div><canvas id="customerChart"></canvas></div>
</div>

<!-- ===== ORDERS TABLE ===== -->
<div class="table-container">
  <table class="table-premium">
    <thead>
      <tr>
        <th>ID</th><th>Customer</th><th>Total</th><th>Status</th><th>Payment</th><th>Action</th>
      </tr>
    </thead>
    <tbody>
      {% for order in page_obj %}
      <tr>
        <td class="order-id">#{{ order.id }}</td>
        <td>{{ order.customer.name }}</td>
        <td class="amount">₹{{ order.total_amount|floatformat:2 }}</td>
        <td>
          <span class="badge-premium
            {% if order.status == 'ready' %}badge-ready
            {% elif order.status == 'completed' %}badge-completed
            {% elif order.status == 'cancelled' %}badge-cancelled
            {% else %}badge-pending{% endif %}">
            {{ order.status|title }}
          </span>
        </td>
        <td>
          <span class="badge-premium
            {% if order.payment_status == 'paid' %}badge-paid
            {% elif order.payment_status == 'partial' %}badge-partial
            {% else %}badge-unpaid{% endif %}">
            {{ order.payment_status|title }}
          </span>
        </td>
        <td>
          <a href="/portal/{{ tenant.schema_name }}/chakki/order/{{ order.id }}/" class="btn btn-sm btn-outline-primary">View</a>
        </td>
      </tr>
      {% empty %}
      <tr><td colspan="6"><div class="empty-state"><i class="fas fa-inbox"></i><p>No orders.</p></div></td></tr>
      {% endfor %}
    </tbody>
  </table>
</div>

<!-- ===== PAGINATION ===== -->
{% if page_obj.has_other_pages %}
<div class="pagination-wrap">
  <div class="step-links">
    {% if page_obj.has_previous %}
      <a href="?page=1{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">&laquo;</a>
      <a href="?page={{ page_obj.previous_page_number }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">‹</a>
    {% else %}
      <span class="disabled">&laquo;</span><span class="disabled">‹</span>
    {% endif %}

    <span class="current">{{ page_obj.number }}</span>

    {% if page_obj.has_next %}
      <a href="?page={{ page_obj.next_page_number }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">›</a>
      <a href="?page={{ page_obj.paginator.num_pages }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if search %}&search={{ search }}{% endif %}">&raquo;</a>
    {% else %}
      <span class="disabled">›</span><span class="disabled">&raquo;</span>
    {% endif %}
  </div>
</div>
{% endif %}

<script>
  document.addEventListener('DOMContentLoaded', function() {
    new Chart(document.getElementById('revenueChart'), {
      type: 'line',
      data: { labels: {{ revenue_labels|safe }}, datasets: [{ label: 'Revenue', data: {{ revenue_data }}, borderColor: '#e67e22', backgroundColor: 'rgba(230,126,34,0.1)', tension:0.2, fill:true }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
    });
    new Chart(document.getElementById('ordersChart'), {
      type: 'bar',
      data: { labels: {{ orders_labels|safe }}, datasets: [{ label: 'Orders', data: {{ orders_data }}, backgroundColor: 'rgba(26,42,58,0.6)', borderColor: 'var(--accent)', borderWidth:1 }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, stepSize:1 } } }
    });
    new Chart(document.getElementById('statusChart'), {
      type: 'doughnut',
      data: { labels: {{ order_labels|safe }}, datasets: [{ data: {{ order_data }}, backgroundColor: ['#f1c40f','#3498db','#2ecc71','#e74c3c'] }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }
    });
    new Chart(document.getElementById('paymentChart'), {
      type: 'doughnut',
      data: { labels: {{ payment_labels|safe }}, datasets: [{ data: {{ payment_data }}, backgroundColor: ['#e74c3c','#f39c12','#2ecc71'] }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }
    });
    new Chart(document.getElementById('categoryChart'), {
      type: 'bar',
      data: { labels: {{ cat_labels|safe }}, datasets: [{ label: 'Revenue', data: {{ cat_data }}, backgroundColor: 'rgba(26,42,58,0.7)', borderColor: 'var(--accent)', borderWidth:2 }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
    });
    new Chart(document.getElementById('customerChart'), {
      type: 'bar',
      data: { labels: {{ cust_labels|safe }}, datasets: [{ label: 'Revenue', data: {{ cust_data }}, backgroundColor: 'rgba(230,126,34,0.7)', borderColor: '#e67e22', borderWidth:2 }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
    });
  });
</script>
{% endblock %}
'''

# ----------------------------------------------------------------------
# PATCHER ENGINE
# ----------------------------------------------------------------------

def backup_file(filepath):
    backup = filepath + '.bak'
    if os.path.exists(filepath):
        shutil.copy2(filepath, backup)
        print(f"📁 Backed up: {filepath} -> {backup}")
    else:
        print(f"⚠️  File not found: {filepath}")


def replace_dashboard_function(views_path):
    """Replace the dashboard function in views.py with the new one."""
    if not os.path.exists(views_path):
        print(f"❌ {views_path} not found.")
        return False

    with open(views_path, 'r') as f:
        content = f.read()

    # Find the dashboard function block
    # We'll locate the start of the function and the next function (or end of file)
    lines = content.splitlines(keepends=True)
    start_line = -1
    end_line = -1

    # Find the line with 'def dashboard(request, **kwargs):'
    for i, line in enumerate(lines):
        if re.match(r'^def dashboard\(request,\s*\*\*kwargs\):', line):
            start_line = i
            break
    if start_line == -1:
        print("❌ Could not find 'def dashboard(request, **kwargs):' in views.py")
        return False

    # Find the next function definition (starts with 'def ') or the end
    # Start looking after the start_line
    indent_level = len(lines[start_line]) - len(lines[start_line].lstrip())
    for i in range(start_line + 1, len(lines)):
        if lines[i].strip().startswith('def ') and len(lines[i]) - len(lines[i].lstrip()) <= indent_level:
            end_line = i
            break
    if end_line == -1:
        end_line = len(lines)

    # Replace the block with the new function
    new_lines = lines[:start_line] + [NEW_DASHBOARD_VIEW] + lines[end_line:]

    # Write back
    with open(views_path, 'w') as f:
        f.writelines(new_lines)
    print(f"✅ Updated {views_path}")
    return True


def replace_template(template_path, new_content):
    """Overwrite a template file with new content."""
    if not os.path.exists(template_path):
        print(f"⚠️  Template not found: {template_path} – creating it.")
    with open(template_path, 'w') as f:
        f.write(new_content)
    print(f"✅ Updated {template_path}")


def main():
    print("🚀 Starting Mega Reports Dashboard Patcher...")

    # Back up original files
    views_file = 'reports/views.py'
    desktop_template = 'reports/templates/desktop/reports_dashboard.html'
    mobile_template = 'reports/templates/mobile/reports_dashboard.html'

    backup_file(views_file)
    backup_file(desktop_template)
    backup_file(mobile_template)

    # Replace dashboard function
    if replace_dashboard_function(views_file):
        print("✅ Dashboard view replaced.")
    else:
        print("❌ Failed to replace dashboard view.")
        return

    # Replace templates
    replace_template(desktop_template, NEW_DESKTOP_TEMPLATE)
    replace_template(mobile_template, NEW_MOBILE_TEMPLATE)

    print("\n🎉 Patcher completed successfully!")
    print("Now visit: http://localhost:8000/portal/<your-tenant>/reports/")
    print("You'll see the full mega dashboard with all analytics.")

if __name__ == '__main__':
    main()
