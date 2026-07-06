#!/usr/bin/env python3
"""
Fix indentation error in chakki/views.py - add_customer_from_order function.
Run: python3 fix_indentation.py
"""

import re
from pathlib import Path

def main():
    views_path = Path("chakki/views.py")
    if not views_path.exists():
        print("❌ chakki/views.py not found")
        return

    content = views_path.read_text(encoding='utf-8')

    # Find the function and replace its body with the corrected version.
    # We'll match from "def add_customer_from_order" to the next function definition
    # or to the end of the file.
    pattern = r'(def add_customer_from_order\(request, order_id, \*\*kwargs\):.*?)(?=\n@login_required|\Z)'

    corrected_function = '''def add_customer_from_order(request, order_id, **kwargs):
    order = get_object_or_404(ChakkiOrder, id=order_id)
    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        phone = request.POST.get('phone', '').strip()
        address = request.POST.get('address', '').strip()
        if name and phone:
            existing = ChakkiCustomer.objects.filter(phone=phone).first()
            if existing:
                cust = order.customer
                cust.name = name
                cust.phone = phone
                cust.address = address
                cust.is_regular = True
                cust.save()
                messages.success(request, f"Customer updated and added to regulars.")
            else:
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
    return redirect('order_confirmation', schema_name=request.tenant.schema_name, order_id=order_id)'''

    # Replace the function body
    new_content, count = re.subn(pattern, corrected_function, content, flags=re.DOTALL)

    if count == 0:
        print("⚠️ Could not find add_customer_from_order function. Please check manually.")
        return

    views_path.write_text(new_content, encoding='utf-8')
    print(f"✅ Fixed indentation in chakki/views.py ({count} replacement).")

if __name__ == "__main__":
    main()
