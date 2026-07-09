#!/usr/bin/env python3
"""
Patcher to fix blank charts in Orders Report.
Adds missing status_dist_keys, status_dist_values, payment_dist_keys, payment_dist_values to context.
Run: python3 patcher_fix_charts.py
"""
import os
import shutil
from pathlib import Path

VIEWS_PATH = Path('reports/views.py')

# The corrected orders_report function with all context variables
CORRECTED_ORDERS_REPORT = '''
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

    # Convert dict keys/values to lists for template
    status_dist_keys = list(status_dist.keys())
    status_dist_values = list(status_dist.values())
    payment_dist_keys = list(payment_dist.keys())
    payment_dist_values = list(payment_dist.values())

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
        'status_dist_keys': status_dist_keys,
        'status_dist_values': status_dist_values,
        'payment_dist': payment_dist,
        'payment_dist_keys': payment_dist_keys,
        'payment_dist_values': payment_dist_values,
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

def main():
    # Read the current views.py
    if not VIEWS_PATH.exists():
        print(f"❌ {VIEWS_PATH} not found. Are you in the project root?")
        return

    with open(VIEWS_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the orders_report function and replace it
    import re
    # Pattern to match the entire orders_report function
    pattern = r'(# ===== ENHANCED ORDERS REPORT =====\s*@login_required\s*def orders_report\(request, \*\*kwargs\):.*?)(?=\n@login_required|\Z)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not locate orders_report function in views.py. Maybe it has been changed.")
        # Fallback: we'll append the corrected function? Better to warn.
        print("⚠️  Please manually add the missing context variables or use a different method.")
        return

    # Replace the function with the corrected version
    # We need to preserve the rest of the file, so we replace only the matched group.
    new_content = content[:match.start()] + CORRECTED_ORDERS_REPORT + content[match.end():]

    # Backup
    backup = VIEWS_PATH.with_suffix('.bak')
    shutil.copy2(VIEWS_PATH, backup)
    print(f"✅ Backup saved to {backup}")

    # Write the new content
    with open(VIEWS_PATH, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✅ views.py updated with missing chart context variables.")

    print("\n🎉 Done! Restart your server and the charts should now display data.")
    print("🔍 If charts still blank, ensure you have orders in the system and check the browser console for errors.")

if __name__ == '__main__':
    main()
