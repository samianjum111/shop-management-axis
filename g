#!/usr/bin/env python3
"""
Patcher to prevent collecting more than the pending amount.
- Adds max attribute to input field.
- Adds oninput to cap value.
- Updates view with server-side validation.
"""

import re
import os

VIEWS_FILE = 'chakki/views.py'
MOBILE_TEMPLATE = 'templates/mobile/customer_profile.html'
DESKTOP_TEMPLATE = 'templates/desktop/customer_profile.html'

NEW_COLLECT_VIEW = '''
@login_required
def collect_pending(request, customer_id, **kwargs):
    """Collect payment from a customer's pending orders and loans."""
    customer = get_object_or_404(ChakkiCustomer, id=customer_id, tenant=request.tenant)
    if request.method != 'POST':
        messages.error(request, "Invalid request.")
        return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=customer.id)

    amount = Decimal(request.POST.get('amount', '0'))
    if amount <= 0:
        messages.error(request, "Please enter a valid amount.")
        return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=customer.id)

    total_pending = get_customer_total_pending(customer)
    if amount > total_pending:
        messages.error(request, f"Amount cannot exceed total pending (₹{total_pending:.2f}).")
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
'''

def patch_view():
    if not os.path.exists(VIEWS_FILE):
        print("⚠️  views.py not found")
        return
    with open(VIEWS_FILE, 'r') as f:
        content = f.read()
    lines = content.splitlines(keepends=True)
    start_idx = None
    for i, line in enumerate(lines):
        if line.strip().startswith('def collect_pending(request, customer_id, **kwargs):'):
            start_idx = i
            break
    if start_idx is None:
        print("⚠️  collect_pending function not found")
        return
    end_idx = len(lines)
    for i in range(start_idx + 1, len(lines)):
        if lines[i].strip().startswith('def ') and not lines[i].startswith(' '):
            end_idx = i
            break
    new_block = NEW_COLLECT_VIEW.splitlines(keepends=True)
    if new_block[-1] != '\n':
        new_block[-1] += '\n'
    lines[start_idx:end_idx] = new_block
    with open(VIEWS_FILE, 'w') as f:
        f.writelines(lines)
    print("✅ Updated collect_pending view")

def patch_template(filepath, is_mobile=False):
    if not os.path.exists(filepath):
        print(f"⚠️  {filepath} not found")
        return
    with open(filepath, 'r') as f:
        content = f.read()
    # Find the input field in collect modal
    # Pattern: <input type="number" name="amount" class="form-control" step="0.01" min="0.01" required>
    # We'll replace it with the full version.
    new_input = '<input type="number" name="amount" class="form-control" step="0.01" min="0.01" max="{{ total_pending|floatformat:2 }}" required oninput="if(parseFloat(this.value) > parseFloat(this.max)) this.value = this.max; this.setCustomValidity(\'\')" oninvalid="this.setCustomValidity(\'Amount cannot exceed total pending.\')" />'
    pattern = r'<input type="number" name="amount" class="form-control" step="0.01" min="0.01" required[^>]*>'
    new_content = re.sub(pattern, new_input, content)
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"✅ Updated {filepath}")
    else:
        print(f"ℹ️  No change in {filepath}")

if __name__ == '__main__':
    patch_view()
    patch_template(MOBILE_TEMPLATE)
    patch_template(DESKTOP_TEMPLATE)
