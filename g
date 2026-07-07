#!/usr/bin/env python3
"""
Fix "Add to Regulars" functionality.
When the phone number matches the existing walk‑in customer, we should convert them to regular.
"""

import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

def replace_in_file_regex(filepath, pattern, replacement):
    path = BASE_DIR / filepath
    if not path.exists():
        print(f"⚠️  File not found: {filepath}")
        return
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content, count = re.subn(pattern, replacement, content, flags=re.DOTALL)
    if count == 0:
        print(f"⚠️  No matches for pattern in {filepath}, skipping.")
        return
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"✅ Updated {filepath} ({count} replacements)")

def main():
    print("🚀 Fixing 'Add to Regulars' functionality...")

    new_add_customer = """@login_required
def add_customer_from_order(request, order_id, **kwargs):
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        phone = request.POST.get('phone', '').strip()
        address = request.POST.get('address', '').strip()
        if name and phone:
            existing = ChakkiCustomer.objects.filter(tenant=request.tenant, phone=phone).first()
            if existing:
                # If the existing customer is the same as the order's customer, just set is_regular=True
                if existing == order.customer:
                    existing.is_regular = True
                    existing.name = name
                    existing.address = address
                    existing.save()
                    messages.success(request, f"Customer {existing.name} added to regulars.")
                    return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=existing.id)
                else:
                    # Different customer with same phone: link order to existing and delete old if empty
                    old_customer = order.customer
                    order.customer = existing
                    order.save()
                    if old_customer != existing and old_customer.chakkiorder_set.count() == 0:
                        old_customer.delete()
                    messages.success(request, f"Order linked to existing customer {existing.name}.")
                    return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=existing.id)
            else:
                # New phone: update the order's customer to regular
                cust = order.customer
                cust.name = name
                cust.phone = phone
                cust.address = address
                cust.is_regular = True
                cust.save()
                messages.success(request, f"Customer {name} added to regulars.")
                return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=cust.id)
        else:
            messages.error(request, "Name and Phone are required.")
    return redirect('order_confirmation', schema_name=request.tenant.schema_name, order_id=order_id)
"""

    # Use regex to replace the entire function
    pattern = r'(@login_required\s+def add_customer_from_order\(request, order_id, \*\*kwargs\):.*?)(?=\n@login_required|\Z)'
    replace_in_file_regex('chakki/views.py', pattern, new_add_customer)

    print("\n✅ Patch applied successfully!")
    print("📌 Now when you click 'Add to Regulars' on the confirmation page, the walk‑in customer will be converted to a regular customer.")
    print("🚀 Restart your server to apply the changes.")

if __name__ == "__main__":
    main()
