#!/usr/bin/env python3
"""
Patcher to fix 'Collect Pending' for completed partial orders.
Run: python3 patcher2.py
"""

import re

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def patch_views():
    path = 'chakki/views.py'
    content = read_file(path)

    # Define the new complete_order_action function
    new_func = '''
@login_required
def complete_order_action(request, order_id, **kwargs):
    """Unified completion: handles full and partial payments on one page."""
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)

    # If order is completed and fully paid, nothing to do.
    if order.status == 'completed' and order.remaining_amount == 0:
        messages.info(request, f"Order #{order.id} is already completed and fully paid.")
        return redirect('chakki_home', schema_name=request.tenant.schema_name)

    if request.method == 'POST':
        payment_choice = request.POST.get('payment_choice')
        if payment_choice == 'full':
            # Pay remaining in full
            order.amount_paid = order.total_amount
            if order.status != 'completed':
                order.status = 'completed'
                order.completed_at = timezone.now()
            order.save()
            messages.success(request, f"Order #{order.id} completed with full payment.")
            return redirect('chakki_home', schema_name=request.tenant.schema_name)

        elif payment_choice == 'partial':
            receive_amount = Decimal(request.POST.get('receive_amount', 0))
            if receive_amount > 0:
                new_paid = order.amount_paid + receive_amount
                if new_paid > order.total_amount:
                    new_paid = order.total_amount
                order.amount_paid = new_paid
                # Only set status to completed if it wasn't already
                if order.status != 'completed':
                    order.status = 'completed'
                    order.completed_at = timezone.now()
                order.save()
                messages.success(request,
                    f"Order #{order.id} completed. Received ₹{receive_amount:.2f}. "
                    f"Remaining balance: ₹{order.remaining_amount:.2f}")
                return redirect('chakki_home', schema_name=request.tenant.schema_name)
            else:
                messages.error(request, "Please enter a valid amount to receive.")
        else:
            messages.error(request, "Invalid payment choice.")
        # If error, re‑render the page with messages

    # GET or after POST error: show the confirmation page with payment options if partial
    context = {
        'order': order,
        'tenant': request.tenant,
        'partial': order.remaining_amount > 0,   # flag for template
        'remaining': order.remaining_amount,
    }
    template = 'mobile/order_complete_confirm.html' if request.mobile else 'desktop/order_complete_confirm.html'
    return render(request, template, context)
'''

    # Find the existing function and replace it
    # We'll match from '@login_required\ndef complete_order_action' to the next '@login_required' or end.
    pattern = r'@login_required\s+def complete_order_action\(request, order_id, \*\*kwargs\):.*?(?=\n@login_required|\Z)'
    # Use re.DOTALL to match across lines
    match = re.search(pattern, content, re.DOTALL)
    if match:
        old_func = match.group(0)
        # Replace with new function
        content = content.replace(old_func, new_func.strip())
        write_file(path, content)
        print("✅ Updated complete_order_action in chakki/views.py")
    else:
        print("❌ Could not find complete_order_action function. Please check the file.")

def main():
    print("🚀 Applying patch for completed partial orders...")
    patch_views()
    print("✅ Patch applied. Restart your server to see changes.")

if __name__ == '__main__':
    main()
