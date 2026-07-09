#!/usr/bin/env python3
"""
Patcher for Orders Report – adds mega analytics, tabs (All/Regular/Walk-in), filters, charts, and sortable table.
Run from project root: python3 patcher.py
"""
import os
import shutil
from pathlib import Path

# ----------------------------------------------------------------------
# NEW CONTENT for reports/views.py – replace the whole file with enhanced version.
# We keep all existing views unchanged, only orders_report is upgraded.
# ----------------------------------------------------------------------
NEW_VIEWS = '''from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.db.models import Sum, Count, Q, Avg
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from chakki.models import ChakkiOrder, ChakkiCategory, SellingCategory, ChakkiCustomer, SellingOrderItem, ChakkiOrderItem
from expenses.models import Expense
from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
from datetime import datetime

@login_required
def dashboard(request, **kwargs):
    tenant = request.tenant
    orders = ChakkiOrder.objects.filter(tenant=tenant)
    completed_orders = orders.filter(status='completed')
    pending_orders = orders.filter(status='pending')
    ready_orders = orders.filter(status='ready')

    total_revenue = completed_orders.aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
    total_pending = Decimal('0')
    for order in orders.exclude(status='completed'):
        total_pending += order.remaining_amount

    total_orders = orders.count()
    completed_count = completed_orders.count()

    # Revenue over last 30 days
    today = timezone.now().date()
    revenue_labels = []
    revenue_data = []
    for i in range(29, -1, -1):
        day = today - timedelta(days=i)
        revenue_labels.append(day.strftime('%d %b'))
        day_total = orders.filter(
            status='completed',
            created_at__date=day
        ).aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        revenue_data.append(float(day_total))

    # Order status counts
    status_data = {
        'Pending': orders.filter(status='pending').count(),
        'Ready': orders.filter(status='ready').count(),
        'Completed': orders.filter(status='completed').count(),
        'Cancelled': orders.filter(status='cancelled').count(),
    }

    # Recent orders
    recent_orders = orders.order_by('-created_at')[:10]

    context = {
        'total_revenue': total_revenue,
        'total_pending': total_pending,
        'total_orders': total_orders,
        'completed_count': completed_count,
        'revenue_labels': revenue_labels,
        'revenue_data': revenue_data,
        'status_data': status_data,
        'recent_orders': recent_orders,
        'tenant': tenant,
    }
    template = 'mobile/reports_dashboard.html' if request.mobile else 'desktop/reports_dashboard.html'
    return render(request, template, context)

@login_required
def revenue(request, **kwargs):
    tenant = request.tenant
    orders = ChakkiOrder.objects.filter(tenant=tenant, status='completed').order_by('-created_at')
    total_revenue = orders.aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
    # Group by date for chart
    today = timezone.now().date()
    revenue_by_day = {}
    for i in range(29, -1, -1):
        day = today - timedelta(days=i)
        day_total = orders.filter(created_at__date=day).aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        revenue_by_day[day.strftime('%d %b')] = float(day_total)

    context = {
        'orders': orders[:50],
        'total_revenue': total_revenue,
        'revenue_by_day': revenue_by_day,
        'tenant': tenant,
    }
    template = 'mobile/reports_revenue.html' if request.mobile else 'desktop/reports_revenue.html'
    return render(request, template, context)

@login_required
def categories(request, **kwargs):
    tenant = request.tenant

    # Get search and sort parameters
    search = request.GET.get('search', '').strip()
    sort = request.GET.get('sort', 'name')  # name, revenue, orders, profit
    order = request.GET.get('order', 'asc')  # asc or desc

    grinding_cats = ChakkiCategory.objects.filter(tenant=tenant)
    selling_cats = SellingCategory.objects.filter(tenant=tenant)

    all_categories = []

    # Process grinding categories
    for cat in grinding_cats:
        items = cat.chakkiorderitem_set.filter(tenant=tenant)
        total_kg = items.aggregate(Sum('total_kg'))['total_kg__sum'] or Decimal('0')
        total_revenue = items.aggregate(Sum('item_total'))['item_total__sum'] or Decimal('0')
        total_orders = items.values('order').distinct().count()
        all_categories.append({
            'id': cat.id,
            'name': cat.name,
            'type': 'grinding',
            'url_name': 'grinding_category_detail',
            'total_quantity': total_kg,
            'quantity_unit': 'KG',
            'total_revenue': total_revenue,
            'total_orders': total_orders,
            'total_profit': None,
        })

    # Process selling categories
    for cat in selling_cats:
        selling_items = SellingOrderItem.objects.filter(selling_price__category=cat, tenant=tenant)
        total_qty = selling_items.aggregate(Sum('quantity'))['quantity__sum'] or Decimal('0')
        total_revenue = selling_items.aggregate(Sum('total'))['total__sum'] or Decimal('0')
        total_orders = selling_items.values('order').distinct().count()
        total_cost = Decimal('0')
        for item in selling_items:
            total_cost += item.quantity * item.selling_price.purchase_price
        total_profit = total_revenue - total_cost
        all_categories.append({
            'id': cat.id,
            'name': cat.name,
            'type': 'selling',
            'url_name': 'selling_category_detail',
            'total_quantity': total_qty,
            'quantity_unit': 'Qty',
            'total_revenue': total_revenue,
            'total_orders': total_orders,
            'total_profit': total_profit,
        })

    # Apply search filter
    if search:
        all_categories = [c for c in all_categories if search.lower() in c['name'].lower()]

    # Apply sorting
    reverse = (order == 'desc')
    if sort == 'name':
        all_categories.sort(key=lambda x: x['name'].lower(), reverse=reverse)
    elif sort == 'revenue':
        all_categories.sort(key=lambda x: x['total_revenue'], reverse=reverse)
    elif sort == 'orders':
        all_categories.sort(key=lambda x: x['total_orders'], reverse=reverse)
    elif sort == 'profit':
        all_categories.sort(key=lambda x: x['total_profit'] or Decimal('0'), reverse=reverse)

    # Aggregated KPIs
    total_categories = len(all_categories)
    total_revenue = sum(c['total_revenue'] for c in all_categories)
    total_orders = sum(c['total_orders'] for c in all_categories)
    total_profit = sum(c['total_profit'] or Decimal('0') for c in all_categories)
    avg_revenue = total_revenue / total_categories if total_categories else 0

    # For chart: category name vs revenue
    chart_labels = [c['name'] for c in all_categories]
    chart_data = [float(c['total_revenue']) for c in all_categories]

    context = {
        'categories': all_categories,
        'total_categories': total_categories,
        'total_revenue': total_revenue,
        'total_orders': total_orders,
        'total_profit': total_profit,
        'avg_revenue': avg_revenue,
        'search': search,
        'sort': sort,
        'order': order,
        'chart_labels': chart_labels,
        'chart_data': chart_data,
        'tenant': tenant,
    }
    template = 'mobile/reports_categories.html' if request.mobile else 'desktop/reports_categories.html'
    return render(request, template, context)

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

# ===== ENHANCED ORDERS REPORT =====
@login_required
def orders_report(request, **kwargs):
    from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
    from django.db.models import Q, Sum, Count, Avg
    from decimal import Decimal
    from datetime import datetime, timedelta

    tenant = request.tenant
    customer_type = request.GET.get('customer_type', 'all')  # all, regular, walkin

    orders = ChakkiOrder.objects.filter(tenant=tenant)
    if customer_type == 'regular':
        orders = orders.filter(customer__is_regular=True)
    elif customer_type == 'walkin':
        orders = orders.filter(customer__is_regular=False)
    # else all

    # ----- Filters -----
    start_date = request.GET.get('start_date')
    end_date = request.GET.get('end_date')
    status = request.GET.get('status')
    search = request.GET.get('search', '').strip()
    sort = request.GET.get('sort', 'created_at')
    order = request.GET.get('order', 'desc')
    page = request.GET.get('page', 1)

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
    if status and status != 'all':
        orders = orders.filter(status=status)
    if search:
        orders = orders.filter(
            Q(customer__name__icontains=search) |
            Q(customer__phone__icontains=search) |
            Q(id__icontains=search)
        )

    # ----- Aggregates -----
    total_orders = orders.count()
    completed_orders = orders.filter(status='completed')
    total_revenue = completed_orders.aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
    total_paid = orders.aggregate(Sum('amount_paid'))['amount_paid__sum'] or Decimal('0')
    total_pending = Decimal('0')
    for o in orders.exclude(status='completed'):
        total_pending += o.remaining_amount
    avg_order_value = completed_orders.aggregate(Avg('total_amount'))['total_amount__avg'] or Decimal('0')

    # Status distribution
    status_dist = {
        'Pending': orders.filter(status='pending').count(),
        'Ready': orders.filter(status='ready').count(),
        'Completed': orders.filter(status='completed').count(),
        'Cancelled': orders.filter(status='cancelled').count(),
    }

    # Payment status distribution
    payment_dist = {
        'Unpaid': orders.filter(payment_status='unpaid').count(),
        'Partial': orders.filter(payment_status='partial').count(),
        'Paid': orders.filter(payment_status='paid').count(),
    }

    # Revenue trend last 30 days
    today = timezone.now().date()
    revenue_labels = []
    revenue_data = []
    for i in range(29, -1, -1):
        day = today - timedelta(days=i)
        revenue_labels.append(day.strftime('%d %b'))
        day_total = completed_orders.filter(created_at__date=day).aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        revenue_data.append(float(day_total))

    # Orders trend last 30 days
    orders_data = []
    for i in range(29, -1, -1):
        day = today - timedelta(days=i)
        count = orders.filter(created_at__date=day).count()
        orders_data.append(count)

    # Top 10 customers by revenue (completed orders)
    top_customers = {}
    for order in completed_orders:
        cid = order.customer.id
        top_customers[cid] = top_customers.get(cid, Decimal('0')) + order.total_amount
    top_customers_list = sorted(top_customers.items(), key=lambda x: x[1], reverse=True)[:10]
    top_customer_labels = []
    top_customer_data = []
    for cid, rev in top_customers_list:
        customer = ChakkiCustomer.objects.get(id=cid)
        top_customer_labels.append(customer.name)
        top_customer_data.append(float(rev))

    # Top 5 categories by revenue (both grinding and selling)
    cat_revenue = {}
    grinding_items = ChakkiOrderItem.objects.filter(order__in=completed_orders, tenant=tenant)
    for item in grinding_items:
        name = item.category.name
        cat_revenue[name] = cat_revenue.get(name, Decimal('0')) + item.item_total
    selling_items = SellingOrderItem.objects.filter(order__in=completed_orders, tenant=tenant)
    for item in selling_items:
        name = item.selling_price.category.name
        cat_revenue[name] = cat_revenue.get(name, Decimal('0')) + item.total
    top_cats = sorted(cat_revenue.items(), key=lambda x: x[1], reverse=True)[:5]
    cat_labels = [cat for cat, _ in top_cats]
    cat_data = [float(rev) for _, rev in top_cats]

    # ----- Sorting for table -----
    if sort == 'id':
        sort_field = 'id'
    elif sort == 'customer':
        sort_field = 'customer__name'
    elif sort == 'total':
        sort_field = 'total_amount'
    elif sort == 'paid':
        sort_field = 'amount_paid'
    elif sort == 'remaining':
        sort_field = 'remaining_amount'   # not a DB field, handled below
    elif sort == 'status':
        sort_field = 'status'
    elif sort == 'payment_status':
        sort_field = 'payment_status'
    else:
        sort_field = 'created_at'

    if sort_field == 'remaining_amount':
        orders_list = list(orders)
        orders_list.sort(key=lambda o: o.remaining_amount, reverse=(order == 'desc'))
    else:
        if order == 'desc':
            sort_field = '-' + sort_field
        orders_list = orders.order_by(sort_field)

    # ----- Pagination -----
    paginator = Paginator(orders_list, 30)
    try:
        page_obj = paginator.page(page)
    except (EmptyPage, PageNotAnInteger):
        page_obj = paginator.page(1)

    context = {
        'page_obj': page_obj,
        'total_orders': total_orders,
        'total_revenue': total_revenue,
        'total_paid': total_paid,
        'total_pending': total_pending,
        'avg_order_value': avg_order_value,
        'status_dist': status_dist,
        'payment_dist': payment_dist,
        'revenue_labels': revenue_labels,
        'revenue_data': revenue_data,
        'orders_data': orders_data,
        'top_customer_labels': top_customer_labels,
        'top_customer_data': top_customer_data,
        'cat_labels': cat_labels,
        'cat_data': cat_data,
        'tenant': tenant,
        'start_date': start_date,
        'end_date': end_date,
        'status': status,
        'search': search,
        'sort': sort,
        'order': order,
        'customer_type': customer_type,
    }
    template = 'mobile/reports_orders.html' if request.mobile else 'desktop/reports_orders.html'
    return render(request, template, context)'''

# ----------------------------------------------------------------------
# NEW CONTENT for reports/templates/desktop/reports_orders.html
# Mega dashboard with tabs (All/Regular/Walk-in), filters, KPIs, 6 charts, table.
# ----------------------------------------------------------------------
NEW_TEMPLATE = '''{% extends "desktop/base.html" %}
{% load static %}
{% block title %}Orders Report | {{ tenant.name }}{% endblock %}
{% block extra_head %}
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
  /* ===== Premium Orders Report ===== */
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.8rem;
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
    margin-right: 0.5rem;
  }

  /* Customer type tabs */
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

  /* Filter bar */
  .filter-bar {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 20px;
    padding: 1rem 1.5rem;
    margin-bottom: 2rem;
    box-shadow: 0 2px 12px rgba(0,0,0,0.03);
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    gap: 1rem;
  }
  .filter-bar .form-group {
    flex: 1 1 160px;
    min-width: 120px;
  }
  .filter-bar .form-group label {
    display: block;
    font-weight: 600;
    font-size: 0.75rem;
    text-transform: uppercase;
    color: var(--muted);
    letter-spacing: 0.04em;
    margin-bottom: 0.2rem;
  }
  .filter-bar .form-control,
  .filter-bar .form-select {
    border-radius: 40px;
    border: 1.5px solid var(--border);
    padding: 0.4rem 1rem;
    font-size: 0.9rem;
    background: var(--bg);
    color: var(--text);
    transition: 0.2s;
    width: 100%;
  }
  .filter-bar .form-control:focus,
  .filter-bar .form-select:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 4px rgba(26,42,58,0.06);
    outline: none;
  }
  .filter-bar .btn-apply {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: 40px;
    padding: 0.4rem 1.6rem;
    font-weight: 600;
    font-size: 0.9rem;
    cursor: pointer;
    transition: 0.2s;
    box-shadow: 0 4px 12px rgba(26,42,58,0.15);
    flex: 0 0 auto;
  }
  .filter-bar .btn-apply:hover {
    background: var(--accent-hover);
    transform: translateY(-2px);
  }
  .filter-bar .btn-clear {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 40px;
    padding: 0.4rem 1.2rem;
    font-weight: 600;
    font-size: 0.9rem;
    color: var(--text-secondary);
    text-decoration: none;
    transition: 0.2s;
    flex: 0 0 auto;
  }
  .filter-bar .btn-clear:hover {
    background: var(--surface-alt);
    border-color: var(--accent);
    color: var(--accent);
  }

  /* KPI Cards */
  .kpi-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
  }
  .kpi-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 1rem 0.6rem;
    text-align: center;
    box-shadow: 0 2px 8px rgba(0,0,0,0.02);
    transition: 0.25s;
  }
  .kpi-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 28px rgba(0,0,0,0.06);
    border-color: var(--accent);
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
    margin-top: 0.1rem;
  }
  .kpi-card .icon {
    font-size: 1.4rem;
    color: var(--accent);
    margin-bottom: 0.2rem;
    display: block;
  }

  /* Charts grid */
  .charts-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    margin-bottom: 2rem;
  }
  .chart-box {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 20px;
    padding: 1rem 1rem 0.5rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.02);
    transition: 0.25s;
  }
  .chart-box:hover {
    box-shadow: 0 8px 28px rgba(0,0,0,0.05);
  }
  .chart-box .chart-title {
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--text-secondary);
    margin-bottom: 0.3rem;
  }
  .chart-box canvas {
    max-height: 200px;
    width: 100% !important;
  }
  .chart-box.full-width {
    grid-column: 1 / -1;
  }
  .chart-box.full-width canvas {
    max-height: 220px;
  }

  /* Table */
  .table-container {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 20px;
    padding: 0.5rem 0;
    box-shadow: 0 2px 12px rgba(0,0,0,0.03);
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }
  .table-premium {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    font-size: 0.9rem;
    min-width: 700px;
  }
  .table-premium thead th {
    background: var(--surface-alt);
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 0.8rem 1rem;
    border-bottom: 1px solid var(--border);
    position: sticky;
    top: 0;
    z-index: 2;
    white-space: nowrap;
  }
  .table-premium thead th a {
    color: inherit;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    gap: 0.2rem;
  }
  .table-premium thead th a:hover {
    color: var(--accent);
  }
  .table-premium tbody td {
    padding: 0.7rem 1rem;
    border-bottom: 1px solid var(--border);
    color: var(--text);
    vertical-align: middle;
  }
  .table-premium tbody tr:last-child td {
    border-bottom: none;
  }
  .table-premium tbody tr:hover td {
    background: var(--bg);
  }
  .table-premium .order-id {
    font-weight: 600;
    color: var(--accent);
  }
  .table-premium .amount {
    font-weight: 600;
    white-space: nowrap;
  }

  .badge-premium {
    display: inline-block;
    padding: 0.2rem 0.7rem;
    border-radius: 40px;
    font-weight: 600;
    font-size: 0.7rem;
    text-transform: capitalize;
  }
  .badge-ready { background: #fff3cd; color: #856404; }
  .badge-completed { background: #d4edda; color: #155724; }
  .badge-pending { background: #e2e3e5; color: #383d41; }
  .badge-cancelled { background: #f8d7da; color: #b02a37; }
  .badge-paid { background: #d4edda; color: #155724; }
  .badge-partial { background: #d1ecf1; color: #0c5460; }
  .badge-unpaid { background: #f8d7da; color: #b02a37; }

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

  /* Pagination */
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

  @media (max-width: 992px) {
    .charts-grid { grid-template-columns: 1fr; }
    .filter-bar .form-group { flex: 1 1 100%; }
  }
  @media (max-width: 768px) {
    .page-header { flex-direction: column; align-items: stretch; }
    .kpi-grid { grid-template-columns: 1fr 1fr; }
    .table-container { padding: 0; }
    .table-premium { font-size: 0.8rem; }
    .table-premium thead th, .table-premium tbody td { padding: 0.5rem 0.6rem; }
  }
  @media (max-width: 576px) {
    .page-header h2 { font-size: 1.6rem; }
    .kpi-grid { grid-template-columns: 1fr; }
  }
</style>
{% endblock %}

{% block content %}

<!-- ===== PAGE HEADER ===== -->
<div class="page-header">
  <h2><i class="fas fa-clipboard-list"></i> Orders Report</h2>
</div>

<!-- ===== CUSTOMER TYPE TABS ===== -->
<div class="tabs-bar">
  <a href="?customer_type=all{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}" class="tab-link {% if customer_type == 'all' %}active{% endif %}">
    All <span class="badge">{{ total_orders }}</span>
  </a>
  <a href="?customer_type=regular{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}" class="tab-link {% if customer_type == 'regular' %}active{% endif %}">
    Regular <span class="badge">{{ total_orders }}</span>
  </a>
  <a href="?customer_type=walkin{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}" class="tab-link {% if customer_type == 'walkin' %}active{% endif %}">
    Walk‑in <span class="badge">{{ total_orders }}</span>
  </a>
</div>

<!-- ===== FILTER BAR ===== -->
<form method="get" class="filter-bar">
  <input type="hidden" name="customer_type" value="{{ customer_type }}">
  <div class="form-group">
    <label>From</label>
    <input type="date" name="start_date" class="form-control" value="{{ start_date|default:'' }}">
  </div>
  <div class="form-group">
    <label>To</label>
    <input type="date" name="end_date" class="form-control" value="{{ end_date|default:'' }}">
  </div>
  <div class="form-group">
    <label>Status</label>
    <select name="status" class="form-select">
      <option value="all" {% if status == 'all' or not status %}selected{% endif %}>All</option>
      <option value="pending" {% if status == 'pending' %}selected{% endif %}>Pending</option>
      <option value="ready" {% if status == 'ready' %}selected{% endif %}>Ready</option>
      <option value="completed" {% if status == 'completed' %}selected{% endif %}>Completed</option>
      <option value="cancelled" {% if status == 'cancelled' %}selected{% endif %}>Cancelled</option>
    </select>
  </div>
  <div class="form-group" style="flex: 2;">
    <label>Search</label>
    <input type="text" name="search" class="form-control" placeholder="Customer, phone, order ID..." value="{{ search|default:'' }}">
  </div>
  <button type="submit" class="btn-apply"><i class="fas fa-filter"></i> Apply</button>
  <a href="?customer_type={{ customer_type }}" class="btn-clear"><i class="fas fa-times"></i> Clear</a>
</form>

<!-- ===== KPI CARDS ===== -->
<div class="kpi-grid">
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-shopping-cart"></i></span>
    <div class="number">{{ total_orders }}</div>
    <div class="label">Total Orders</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-coins"></i></span>
    <div class="number">₹{{ total_revenue|floatformat:0 }}</div>
    <div class="label">Revenue</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-credit-card"></i></span>
    <div class="number">₹{{ total_paid|floatformat:0 }}</div>
    <div class="label">Total Paid</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-hourglass-half"></i></span>
    <div class="number">₹{{ total_pending|floatformat:0 }}</div>
    <div class="label">Pending Amount</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-chart-line"></i></span>
    <div class="number">₹{{ avg_order_value|floatformat:2 }}</div>
    <div class="label">Avg Order Value</div>
  </div>
</div>

<!-- ===== CHARTS ===== -->
<div class="charts-grid">
  <!-- Revenue Trend -->
  <div class="chart-box">
    <div class="chart-title"><i class="fas fa-chart-line"></i> Revenue Trend (Last 30 Days)</div>
    <canvas id="revenueChart"></canvas>
  </div>
  <!-- Orders Trend -->
  <div class="chart-box">
    <div class="chart-title"><i class="fas fa-chart-bar"></i> Orders Trend (Last 30 Days)</div>
    <canvas id="ordersChart"></canvas>
  </div>
  <!-- Status Distribution -->
  <div class="chart-box">
    <div class="chart-title"><i class="fas fa-doughnut-chart"></i> Order Status</div>
    <canvas id="statusChart"></canvas>
  </div>
  <!-- Payment Status -->
  <div class="chart-box">
    <div class="chart-title"><i class="fas fa-doughnut-chart"></i> Payment Status</div>
    <canvas id="paymentChart"></canvas>
  </div>
  <!-- Top Customers -->
  <div class="chart-box full-width">
    <div class="chart-title"><i class="fas fa-users"></i> Top 10 Customers by Revenue</div>
    <canvas id="customerChart"></canvas>
  </div>
  <!-- Top Categories -->
  <div class="chart-box full-width">
    <div class="chart-title"><i class="fas fa-tags"></i> Top 5 Categories by Revenue</div>
    <canvas id="categoryChart"></canvas>
  </div>
</div>

<!-- ===== ORDERS TABLE ===== -->
<div class="table-container">
  <table class="table-premium">
    <thead>
      <tr>
        <th><a href="?sort=id&order={% if sort == 'id' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}">ID {% if sort == 'id' %}{% if order == 'asc' %}↑{% else %}↓{% endif %}{% endif %}</a></th>
        <th><a href="?sort=customer&order={% if sort == 'customer' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Customer {% if sort == 'customer' %}{% if order == 'asc' %}↑{% else %}↓{% endif %}{% endif %}</a></th>
        <th>Phone</th>
        <th><a href="?sort=total&order={% if sort == 'total' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Total {% if sort == 'total' %}{% if order == 'asc' %}↑{% else %}↓{% endif %}{% endif %}</a></th>
        <th><a href="?sort=paid&order={% if sort == 'paid' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Paid {% if sort == 'paid' %}{% if order == 'asc' %}↑{% else %}↓{% endif %}{% endif %}</a></th>
        <th><a href="?sort=remaining&order={% if sort == 'remaining' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Remaining {% if sort == 'remaining' %}{% if order == 'asc' %}↑{% else %}↓{% endif %}{% endif %}</a></th>
        <th><a href="?sort=status&order={% if sort == 'status' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Status {% if sort == 'status' %}{% if order == 'asc' %}↑{% else %}↓{% endif %}{% endif %}</a></th>
        <th><a href="?sort=payment_status&order={% if sort == 'payment_status' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Payment {% if sort == 'payment_status' %}{% if order == 'asc' %}↑{% else %}↓{% endif %}{% endif %}</a></th>
        <th><a href="?sort=created_at&order={% if sort == 'created_at' and order == 'asc' %}desc{% else %}asc{% endif %}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}">Date {% if sort == 'created_at' %}{% if order == 'asc' %}↑{% else %}↓{% endif %}{% endif %}</a></th>
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
      <a href="?page=1{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">&laquo; First</a>
      <a href="?page={{ page_obj.previous_page_number }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Prev</a>
    {% else %}
      <span class="disabled">&laquo; First</span>
      <span class="disabled">Prev</span>
    {% endif %}

    <span class="current">Page {{ page_obj.number }} of {{ page_obj.paginator.num_pages }}</span>

    {% if page_obj.has_next %}
      <a href="?page={{ page_obj.next_page_number }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Next</a>
      <a href="?page={{ page_obj.paginator.num_pages }}{% if customer_type %}&customer_type={{ customer_type }}{% endif %}{% if start_date %}&start_date={{ start_date }}{% endif %}{% if end_date %}&end_date={{ end_date }}{% endif %}{% if status and status != 'all' %}&status={{ status }}{% endif %}{% if search %}&search={{ search }}{% endif %}{% if sort %}&sort={{ sort }}{% endif %}{% if order %}&order={{ order }}{% endif %}">Last &raquo;</a>
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
        datasets: [{
          label: 'Revenue (₹)',
          data: {{ revenue_data }},
          borderColor: '#e67e22',
          backgroundColor: 'rgba(230,126,34,0.1)',
          tension: 0.2,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true } }
      }
    });

    // Orders Chart
    new Chart(document.getElementById('ordersChart'), {
      type: 'bar',
      data: {
        labels: {{ revenue_labels|safe }},
        datasets: [{
          label: 'Orders',
          data: {{ orders_data }},
          backgroundColor: 'rgba(26,42,58,0.6)',
          borderColor: 'var(--accent)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true, stepSize: 1 } }
      }
    });

    // Status Chart
    new Chart(document.getElementById('statusChart'), {
      type: 'doughnut',
      data: {
        labels: {{ status_dist.keys|safe }},
        datasets: [{
          data: {{ status_dist.values|safe }},
          backgroundColor: ['#f1c40f', '#3498db', '#2ecc71', '#e74c3c']
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { position: 'bottom' } }
      }
    });

    // Payment Status Chart
    new Chart(document.getElementById('paymentChart'), {
      type: 'doughnut',
      data: {
        labels: {{ payment_dist.keys|safe }},
        datasets: [{
          data: {{ payment_dist.values|safe }},
          backgroundColor: ['#e74c3c', '#f39c12', '#2ecc71']
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { position: 'bottom' } }
      }
    });

    // Top Customers Chart
    new Chart(document.getElementById('customerChart'), {
      type: 'bar',
      data: {
        labels: {{ top_customer_labels|safe }},
        datasets: [{
          label: 'Revenue (₹)',
          data: {{ top_customer_data }},
          backgroundColor: 'rgba(26,42,58,0.7)',
          borderColor: 'var(--accent)',
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true } }
      }
    });

    // Top Categories Chart
    new Chart(document.getElementById('categoryChart'), {
      type: 'bar',
      data: {
        labels: {{ cat_labels|safe }},
        datasets: [{
          label: 'Revenue (₹)',
          data: {{ cat_data }},
          backgroundColor: ['#3498db','#e67e22','#2ecc71','#9b59b6','#f1c40f'],
          borderColor: '#fff',
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true } }
      }
    });
  });
</script>

{% endblock %}'''

# ----------------------------------------------------------------------
# PATHS (relative to project root)
# ----------------------------------------------------------------------
VIEWS_PATH = Path('reports/views.py')
TEMPLATE_PATH = Path('reports/templates/desktop/reports_orders.html')

def backup_file(path):
    """Create a backup copy of the file if it exists."""
    if path.exists():
        backup = path.with_suffix(path.suffix + '.bak')
        shutil.copy2(path, backup)
        print(f'✅ Backup created: {backup}')
    else:
        print(f'⚠️  File {path} does not exist, will create new.')

def write_file(path, content):
    """Write content to file, creating directories if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'✅ Written: {path}')

def main():
    print('🚀 Starting Orders Report Mega Patcher...\n')

    # Backup and write views.py
    backup_file(VIEWS_PATH)
    write_file(VIEWS_PATH, NEW_VIEWS)

    # Backup and write template
    backup_file(TEMPLATE_PATH)
    write_file(TEMPLATE_PATH, NEW_TEMPLATE)

    print('\n✅ Done!')
    print('📌 Visit /portal/<your-tenant>/reports/orders/ to see the mega report.')
    print('🔄 If the server is running, changes will reflect after a reload (or restart).')
    print('📊 Now you have full analytics: All / Regular / Walk‑in tabs, working filters, 6 charts, and a sortable table.')

if __name__ == '__main__':
    main()
