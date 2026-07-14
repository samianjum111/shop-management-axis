#!/usr/bin/env python3
"""
Patcher to update customer_list view:
- Add filter (all/pending/paid)
- Sort pending customers first
- Remove unused sort/order
"""

import re
import os

VIEWS_FILE = 'chakki/views.py'

NEW_FUNC = '''
@login_required
def customer_list(request, **kwargs):
    from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
    from django.db.models import Sum, Count, Q
    from decimal import Decimal

    tenant = request.tenant
    tab = request.GET.get('tab', 'regular')
    q = request.GET.get('q', '').strip()
    page = request.GET.get('page', 1)
    status_filter = request.GET.get('filter', 'all')  # all, pending, paid

    all_customers = ChakkiCustomer.objects.filter(tenant=tenant)
    regular_customers = all_customers.filter(is_regular=True)
    walkin_customers = all_customers.filter(is_regular=False)

    if q:
        all_customers = all_customers.filter(Q(name__icontains=q) | Q(phone__icontains=q))
        regular_customers = regular_customers.filter(Q(name__icontains=q) | Q(phone__icontains=q))
        walkin_customers = walkin_customers.filter(Q(name__icontains=q) | Q(phone__icontains=q))

    if tab == 'walk':
        customers_qs = walkin_customers
    else:
        customers_qs = regular_customers
        tab = 'regular'

    customer_data = []
    total_revenue = Decimal('0')
    total_pending_all = Decimal('0')
    total_orders_all = 0

    for c in customers_qs:
        orders = ChakkiOrder.objects.filter(tenant=tenant, customer=c)
        completed = orders.filter(status='completed')
        total_spent = completed.aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        total_orders = orders.count()
        completed_orders = completed.count()
        avg_order = total_spent / completed_orders if completed_orders > 0 else Decimal('0')
        total_pending = get_customer_total_pending(c)
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
        total_revenue += total_spent
        total_pending_all += total_pending
        total_orders_all += total_orders

    # Apply filter
    if status_filter == 'pending':
        customer_data = [c for c in customer_data if c['total_pending'] > 0]
    elif status_filter == 'paid':
        customer_data = [c for c in customer_data if c['total_pending'] == 0]

    if q:
        customer_data = [c for c in customer_data if q.lower() in c['name'].lower() or q in c['phone']]

    # Sorting: pending customers first, then alphabetically by name
    customer_data.sort(key=lambda x: (0 if x['total_pending'] > 0 else 1, x['name'].lower()))

    paginator = Paginator(customer_data, 30)
    try:
        page_obj = paginator.page(page)
    except (EmptyPage, PageNotAnInteger):
        page_obj = paginator.page(1)

    total_customers = len(customer_data)
    avg_customer_value = total_revenue / total_customers if total_customers else 0

    regular_count = ChakkiCustomer.objects.filter(tenant=tenant, is_regular=True).count()
    walk_count = ChakkiCustomer.objects.filter(tenant=tenant, is_regular=False).count()

    context = {
        'page_obj': page_obj,
        'customer_data': page_obj.object_list,
        'total_customers': total_customers,
        'total_revenue': total_revenue,
        'total_pending_all': total_pending_all,
        'avg_customer_value': avg_customer_value,
        'total_orders_all': total_orders_all,
        'regular_count': regular_count,
        'walk_count': walk_count,
        'tab': tab,
        'search_q': q,
        'filter': status_filter,
        'tenant': tenant,
    }
    template = 'mobile/customer_list.html' if request.mobile else 'desktop/customer_list.html'
    return render(request, template, context)
'''

def patch():
    if not os.path.exists(VIEWS_FILE):
        print(f"Error: {VIEWS_FILE} not found. Run from project root.")
        return

    with open(VIEWS_FILE, 'r') as f:
        content = f.read()

    lines = content.splitlines(keepends=True)
    start_idx = None
    for i, line in enumerate(lines):
        if line.strip().startswith('def customer_list(request, **kwargs):'):
            start_idx = i
            break

    if start_idx is None:
        print("Could not find customer_list function. Aborting.")
        return

    # Find decorators above
    decor_start = start_idx
    for i in range(start_idx - 1, -1, -1):
        if lines[i].strip().startswith('@') or lines[i].strip() == '':
            decor_start = i
        else:
            break

    # Find next top-level def
    end_idx = len(lines)
    for i in range(start_idx + 1, len(lines)):
        if lines[i].strip().startswith('def ') and not lines[i].startswith(' '):
            end_idx = i
            break

    new_block = NEW_FUNC.splitlines(keepends=True)
    if new_block[-1] != '\n':
        new_block[-1] += '\n'
    lines[decor_start:end_idx] = new_block

    with open(VIEWS_FILE, 'w') as f:
        f.writelines(lines)

    print("✅ customer_list view updated successfully.")
    print("   - Added 'filter' parameter (all/pending/paid).")
    print("   - Pending customers appear first.")
    print("   - Removed unused 'sort' and 'order' parameters.")

if __name__ == '__main__':
    patch()
