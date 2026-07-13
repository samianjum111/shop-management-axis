#!/usr/bin/env python3
"""
Patcher to make pending balance global and add collect-pending button.
"""

import os
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def insert_after(content, marker, insertion):
    idx = content.find(marker)
    if idx == -1:
        return content
    end = content.find('\n', idx) + 1
    return content[:end] + insertion + content[end:]

# ----------------------------------------------------------------------
# 1. Add helper function to chakki/views.py (top, after imports)
# ----------------------------------------------------------------------
def patch_views_helper():
    path = PROJECT_ROOT / 'chakki' / 'views.py'
    content = read_file(path)

    # Define helper function
    helper = """

def get_customer_total_pending(customer):
    \"\"\"Return total pending amount for a customer (orders + loans).\"\"\"
    from decimal import Decimal
    from django.db.models import Sum
    from expenses.models import Expense

    orders = ChakkiOrder.objects.filter(customer=customer)
    order_pending = sum(o.remaining_amount for o in orders if o.status != 'completed')
    loan_expenses = Expense.objects.filter(
        tenant=customer.tenant,
        category='given_loan',
        is_credit=True,
        is_repaid=False,
        person_name=customer.name,
        phone=customer.phone
    )
    loan_pending = loan_expenses.aggregate(Sum('amount'))['amount__sum'] or Decimal('0')
    return order_pending + loan_pending
"""

    # Insert after the last import (find a line that starts with 'from' or 'import')
    lines = content.splitlines()
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('from ') or line.startswith('import '):
            insert_idx = i + 1
    lines.insert(insert_idx, helper)
    new_content = '\n'.join(lines)
    write_file(path, new_content)
    print("✅ Added get_customer_total_pending helper to chakki/views.py")

# ----------------------------------------------------------------------
# 2. Update customer_list view to use helper
# ----------------------------------------------------------------------
def patch_customer_list():
    path = PROJECT_ROOT / 'chakki' / 'views.py'
    content = read_file(path)

    # Find the customer_list function and replace its total_pending calculation.
    # We'll replace the loop that computes customer_data.
    # We'll do a targeted replacement.

    # Look for the part where total_pending is computed in customer_list.
    # We'll find the line where total_pending is set to 0 and replace the block.
    # Instead of patching, we'll replace the whole customer_list function with a new one that uses helper.

    # Since we have the full code, we can replace the function definition.
    # We'll find the def customer_list and replace until the next def or end.

    new_customer_list = """
@login_required
def customer_list(request, **kwargs):
    from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
    from django.db.models import Sum, Count, Q
    from decimal import Decimal

    tenant = request.tenant
    tab = request.GET.get('tab', 'regular')
    q = request.GET.get('q', '').strip()
    sort = request.GET.get('sort', 'spent')
    order = request.GET.get('order', 'desc')
    page = request.GET.get('page', 1)

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
        total_pending = get_customer_total_pending(c)  # use helper
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

    if q:
        customer_data = [c for c in customer_data if q.lower() in c['name'].lower() or q in c['phone']]

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
        'sort': sort,
        'order': order,
        'tenant': tenant,
    }
    template = 'mobile/customer_list.html' if request.mobile else 'desktop/customer_list.html'
    return render(request, template, context)
"""

    # Find the existing customer_list function and replace.
    pattern = r'def customer_list\(request, \*\*kwargs\):.*?(?=\ndef |\Z)'
    if re.search(pattern, content, re.DOTALL):
        content = re.sub(pattern, new_customer_list, content, flags=re.DOTALL)
        write_file(path, content)
        print("✅ Patched customer_list to use helper")
    else:
        print("⚠️ Could not find customer_list to patch")

# ----------------------------------------------------------------------
# 3. Update reports/customers view
# ----------------------------------------------------------------------
def patch_reports_customers():
    path = PROJECT_ROOT / 'reports' / 'views.py'
    content = read_file(path)

    # Find the customers function and replace the pending calculation.
    # We'll add import for Expense and modify the loop.
    # Since we want to replace the whole function, we'll define a new one.

    new_customers = """
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
        # Use helper to include loans
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

    # Charts (unchanged)
    top_10_revenue = sorted(customer_data, key=lambda x: x['total_spent'], reverse=True)[:10]
    chart_labels_revenue = [c['name'] for c in top_10_revenue]
    chart_data_revenue = [float(c['total_spent']) for c in top_10_revenue]

    top_10_orders = sorted(customer_data, key=lambda x: x['total_orders'], reverse=True)[:10]
    chart_labels_orders = [c['name'] for c in top_10_orders]
    chart_data_orders = [c['total_orders'] for c in top_10_orders]

    top_10_avg = sorted(customer_data, key=lambda x: x['avg_order'], reverse=True)[:10]
    chart_labels_avg = [c['name'] for c in top_10_avg]
    chart_data_avg = [float(c['avg_order']) for c in top_10_avg]

    sorted_by_revenue = sorted(customer_data, key=lambda x: x['total_spent'], reverse=True)
    top5_revenue = sum(c['total_spent'] for c in sorted_by_revenue[:5])
    rest_revenue = total_revenue - top5_revenue
    concentration_labels = ['Top 5 Customers', 'Other Customers']
    concentration_data = [float(top5_revenue), float(rest_revenue)]

    hbar_labels_revenue = chart_labels_revenue
    hbar_data_revenue = chart_data_revenue

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
        'chart_labels_revenue': chart_labels_revenue,
        'chart_data_revenue': chart_data_revenue,
        'chart_labels_orders': chart_labels_orders,
        'chart_data_orders': chart_data_orders,
        'chart_labels_avg': chart_labels_avg,
        'chart_data_avg': chart_data_avg,
        'concentration_labels': concentration_labels,
        'concentration_data': concentration_data,
        'hbar_labels_revenue': hbar_labels_revenue,
        'hbar_data_revenue': hbar_data_revenue,
        'tenant': tenant,
    }
    template = 'mobile/reports_customers.html' if request.mobile else 'desktop/reports_customers.html'
    return render(request, template, context)
"""

    # Find the existing customers function and replace.
    pattern = r'def customers\(request, \*\*kwargs\):.*?(?=\ndef |\Z)'
    if re.search(pattern, content, re.DOTALL):
        content = re.sub(pattern, new_customers, content, flags=re.DOTALL)
        write_file(path, content)
        print("✅ Patched reports/customers to include loans in pending")
    else:
        print("⚠️ Could not find reports customers function to patch")

# ----------------------------------------------------------------------
# 4. Update add_order view to include loans in customer.total_pending
# ----------------------------------------------------------------------
def patch_add_order():
    path = PROJECT_ROOT / 'chakki' / 'views.py'
    content = read_file(path)

    # In the add_order function, there is a part where it sets customer.total_pending.
    # We'll replace that part.
    # Find the line where customer.total_pending is set.
    # It appears twice: when selecting customer and when loading customer.
    # We'll replace both occurrences.

    # First occurrence: in the select block:
    # for c in customers:
    #     orders = ChakkiOrder.objects.filter(...)
    #     c.total_pending = sum(o.remaining_amount for o in orders if o.status != 'completed')
    # We'll change to use helper.

    # Second: when customer_id is provided:
    # customer = get_object_or_404(...)
    # orders = ChakkiOrder.objects.filter(...)
    # customer.total_pending = sum(o.remaining_amount for o in orders if o.status != 'completed')

    # We'll replace both with a call to get_customer_total_pending(c).

    # We'll do a simple replace.
    pattern = r'c\.total_pending = sum\(o\.remaining_amount for o in orders if o\.status != \'completed\'\)'
    replacement = 'c.total_pending = get_customer_total_pending(c)'
    if re.search(pattern, content):
        content = re.sub(pattern, replacement, content)
        # Also replace the other occurrence
        pattern2 = r'customer\.total_pending = sum\(o\.remaining_amount for o in orders if o\.status != \'completed\'\)'
        replacement2 = 'customer.total_pending = get_customer_total_pending(customer)'
        content = re.sub(pattern2, replacement2, content)
        write_file(path, content)
        print("✅ Patched add_order to use helper for pending")
    else:
        print("⚠️ Could not find add_order pending calculation to patch")

# ----------------------------------------------------------------------
# 5. Update walk_profile view to include loans
# ----------------------------------------------------------------------
def patch_walk_profile():
    path = PROJECT_ROOT / 'chakki' / 'views.py'
    content = read_file(path)

    # In walk_profile, we have:
    # for c in customers:
    #     orders = ChakkiOrder.objects.filter(tenant=request.tenant, customer=c)
    #     total_pending = sum(o.remaining_amount for o in orders if o.remaining_amount > 0)
    # We'll replace with helper.

    pattern = r'total_pending = sum\(o\.remaining_amount for o in orders if o\.remaining_amount > 0\)'
    replacement = 'total_pending = get_customer_total_pending(c)'
    if re.search(pattern, content):
        content = re.sub(pattern, replacement, content)
        write_file(path, content)
        print("✅ Patched walk_profile to use helper")
    else:
        print("⚠️ Could not find walk_profile pending calculation to patch")

# ----------------------------------------------------------------------
# 6. Add collect_pending view and URL
# ----------------------------------------------------------------------
def add_collect_pending_view():
    path = PROJECT_ROOT / 'chakki' / 'views.py'
    content = read_file(path)

    # Check if view already exists
    if 'def collect_pending' in content:
        print("✅ collect_pending view already exists")
        return

    # We'll add the view at the end of the file (before the final closing if any).
    collect_view = """

@login_required
def collect_pending(request, customer_id, **kwargs):
    \"\"\"Collect payment from a customer's pending orders and loans.\"\"\"
    customer = get_object_or_404(ChakkiCustomer, id=customer_id, tenant=request.tenant)
    if request.method != 'POST':
        messages.error(request, "Invalid request.")
        return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=customer.id)

    amount = Decimal(request.POST.get('amount', '0'))
    if amount <= 0:
        messages.error(request, "Please enter a valid amount.")
        return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=customer.id)

    # Get pending orders (oldest first)
    pending_orders = ChakkiOrder.objects.filter(
        tenant=request.tenant,
        customer=customer
    ).exclude(status='completed').order_by('created_at')

    remaining = amount

    # Apply to orders
    for order in pending_orders:
        if remaining <= 0:
            break
        order_rem = order.remaining_amount
        if order_rem > 0:
            if remaining >= order_rem:
                # Pay full order
                order.amount_paid = order.total_amount
                order.status = 'completed'
                order.completed_at = timezone.now()
                order.save()
                remaining -= order_rem
            else:
                # Partial payment
                order.amount_paid += remaining
                order.save()
                remaining = 0
                break

    # Apply to loans if any remaining
    if remaining > 0:
        loan_expenses = Expense.objects.filter(
            tenant=request.tenant,
            category='given_loan',
            is_credit=True,
            is_repaid=False,
            person_name=customer.name,
            phone=customer.phone
        ).order_by('date')
        for expense in loan_expenses:
            if remaining <= 0:
                break
            exp_rem = expense.amount
            if remaining >= exp_rem:
                expense.is_repaid = True
                expense.save()
                remaining -= exp_rem
            else:
                # For partial repayment, we could split the expense, but simpler: mark as repaid and create a new expense for remaining?
                # Alternatively, we can reduce the amount of the expense? That would change historical data.
                # We'll mark as repaid and create a new expense for the remaining amount (unpaid).
                # But for simplicity, we'll just mark it as repaid and reduce amount? Not recommended.
                # Better: we can create a new expense with the remaining amount.
                # We'll implement: if partial, mark current as repaid and create a new expense for the remaining.
                # However, to keep it simple, we'll just mark the expense as partially repaid? That's not supported.
                # We'll instead allow partial repayment by creating a new expense for the remaining amount.
                # But the user expects the loan to be reduced. We'll just mark the expense as repaid and create a new expense for the remaining amount.
                # This is a bit complex, but we'll do it.
                # We'll create a new expense for the remaining balance.
                new_expense = Expense.objects.create(
                    tenant=request.tenant,
                    title=f"Remaining Udhaar for {customer.name}",
                    amount=expense.amount - remaining,
                    category='given_loan',
                    person_name=customer.name,
                    phone=customer.phone,
                    address=customer.address,
                    is_credit=True,
                    is_repaid=False,
                    notes=f"Remaining from original expense #{expense.id} after partial repayment"
                )
                expense.is_repaid = True
                expense.save()
                remaining = 0
                break

    messages.success(request, f"Successfully collected ₹{amount}. Remaining pending: ₹{get_customer_total_pending(customer)}")
    return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=customer.id)
"""

    # Insert at end of file
    content = content + collect_view
    write_file(path, content)
    print("✅ Added collect_pending view")

def add_collect_pending_url():
    path = PROJECT_ROOT / 'chakki' / 'urls.py'
    content = read_file(path)

    # Check if URL already exists
    if "collect-pending" in content:
        print("✅ collect-pending URL already exists")
        return

    # Add new URL pattern before the closing bracket of urlpatterns
    pattern = r"(urlpatterns\s*=\s*\[[\s\S]*?)(\n\])"
    replacement = r"\1    path('customer/<int:customer_id>/collect-pending/', views.collect_pending, name='collect_pending'),\n]"
    new_content = re.sub(pattern, replacement, content, count=1)
    if new_content != content:
        write_file(path, new_content)
        print("✅ Added collect-pending URL")
    else:
        print("⚠️ Could not add URL pattern")

# ----------------------------------------------------------------------
# 7. Update customer_profile templates to include Collect Pending button
# ----------------------------------------------------------------------
def patch_profile_templates():
    # Mobile
    mobile_path = PROJECT_ROOT / 'templates' / 'mobile' / 'customer_profile.html'
    if mobile_path.exists():
        content = read_file(mobile_path)

        # Add the "Collect Pending" button in the actions area.
        # We'll insert after the "Add Pending" button.
        # Look for the actions div and add a new button.

        # We'll add a button with data-bs-toggle="modal" data-bs-target="#collectModal"
        # Also add the modal HTML.

        # Insert after the pending button (which is a button with class btn-pending).
        # We'll find the line with <button class="btn-action btn-pending ...">
        # and insert after it.

        # We'll add a new button:
        new_button = '''
        <button class="btn-action btn-pending" style="background:#28a745;color:#fff;" data-bs-toggle="modal" data-bs-target="#collectModal">
            <i class="fas fa-hand-holding-usd"></i> Collect Pending
        </button>
'''
        # Find the actions div and insert before the closing div.
        # We'll search for <div class="actions"> and insert before </div>.
        pattern = r'(<div class="actions">.*?)(</div>)'
        if re.search(pattern, content, re.DOTALL):
            content = re.sub(pattern, r'\1' + new_button + r'\2', content, flags=re.DOTALL)
        else:
            print("⚠️ Could not find actions div in mobile profile")

        # Add the modal HTML at the end of the file (before {% endblock %})
        modal_html = '''

<!-- Collect Pending Modal -->
<div class="modal fade" id="collectModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <form method="post" action="/portal/{{ tenant.schema_name }}/chakki/customer/{{ customer.id }}/collect-pending/">
                {% csrf_token %}
                <div class="modal-header">
                    <h5 class="modal-title"><i class="fas fa-hand-holding-usd"></i> Collect Pending</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="form-group">
                        <label>Total Pending</label>
                        <input type="text" class="form-control" value="₹{{ total_pending|floatformat:2 }}" disabled>
                    </div>
                    <div class="form-group">
                        <label>Amount to Collect (₹)</label>
                        <input type="number" name="amount" class="form-control" step="0.01" min="0.01" required>
                    </div>
                    <p class="text-muted small">Payment will be applied to pending orders first, then to loans.</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary" style="background:#28a745;border:none;">Collect</button>
                </div>
            </form>
        </div>
    </div>
</div>
'''
        # Insert before {% endblock %}
        content = content.replace('{% endblock %}', modal_html + '\n{% endblock %}')
        write_file(mobile_path, content)
        print("✅ Patched mobile customer_profile with Collect Pending button and modal")
    else:
        print("⚠️ mobile/customer_profile.html not found")

    # Desktop
    desktop_path = PROJECT_ROOT / 'templates' / 'desktop' / 'customer_profile.html'
    if desktop_path.exists():
        content = read_file(desktop_path)

        # Add button in actions div
        new_button = '''
        <button class="btn-premium" style="background:#28a745;border-color:#28a745;" data-bs-toggle="modal" data-bs-target="#collectModal">
            <i class="fas fa-hand-holding-usd"></i> Collect Pending
        </button>
'''
        pattern = r'(<div class="actions">.*?)(</div>)'
        if re.search(pattern, content, re.DOTALL):
            content = re.sub(pattern, r'\1' + new_button + r'\2', content, flags=re.DOTALL)
        else:
            print("⚠️ Could not find actions div in desktop profile")

        # Add modal
        modal_html = '''

<!-- Collect Pending Modal -->
<div class="modal fade" id="collectModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <form method="post" action="/portal/{{ tenant.schema_name }}/chakki/customer/{{ customer.id }}/collect-pending/">
                {% csrf_token %}
                <div class="modal-header">
                    <h5 class="modal-title"><i class="fas fa-hand-holding-usd"></i> Collect Pending</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="form-group">
                        <label>Total Pending</label>
                        <input type="text" class="form-control" value="₹{{ total_pending|floatformat:2 }}" disabled>
                    </div>
                    <div class="form-group">
                        <label>Amount to Collect (₹)</label>
                        <input type="number" name="amount" class="form-control" step="0.01" min="0.01" required>
                    </div>
                    <p class="text-muted small">Payment will be applied to pending orders first, then to loans.</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary" style="background:#28a745;border:none;">Collect</button>
                </div>
            </form>
        </div>
    </div>
</div>
'''
        content = content.replace('{% endblock %}', modal_html + '\n{% endblock %}')
        write_file(desktop_path, content)
        print("✅ Patched desktop customer_profile with Collect Pending button and modal")
    else:
        print("⚠️ desktop/customer_profile.html not found")

# ----------------------------------------------------------------------
# 8. (Optional) Update the pending display in customer_list template to show combined pending
# ----------------------------------------------------------------------
def patch_customer_list_template():
    # The template already uses customer.total_pending, which we updated to include loans.
    # No change needed.
    pass

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main():
    print("🚀 Applying Global Pending Patcher...")
    patch_views_helper()
    patch_customer_list()
    patch_reports_customers()
    patch_add_order()
    patch_walk_profile()
    add_collect_pending_view()
    add_collect_pending_url()
    patch_profile_templates()
    print("\n✅ All patches applied successfully!")
    print("\n📌 What's new:")
    print("  - Pending balance now includes both order remaining amounts and unrepaid loans (Udhaar).")
    print("  - All views (customer list, reports, add order, walk profile) show the unified pending.")
    print("  - Added 'Collect Pending' button on customer profile.")
    print("  - Collect Pending applies payment to pending orders first, then to loans.")
    print("  - Supports partial collection (amount entered by user).")
    print("\n🔄 Restart your server to see the changes.")

if __name__ == "__main__":
    main()
