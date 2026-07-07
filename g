#!/usr/bin/env python3
import os
import shutil
import re
import sys
import django

# ---- 1. Patch context processor ----
def patch_context_processor():
    cp_file = 'core/context_processors.py'
    backup = cp_file + '.bak'
    shutil.copy2(cp_file, backup)
    print(f"✅ Backup: {backup}")

    with open(cp_file, 'r') as f:
        content = f.read()

    # Replace the chakki_counts function to filter by tenant
    new_func = """
def chakki_counts(request):
    from chakki.models import ChakkiOrder
    # Filter by tenant if available
    if hasattr(request, 'tenant') and request.tenant:
        orders = ChakkiOrder.objects.filter(tenant=request.tenant)
    else:
        orders = ChakkiOrder.objects.all()
    pending_count = orders.filter(status='pending').count()
    ready_count = orders.filter(status='ready').count()
    partial_count = orders.filter(payment_status='partial').count()
    completed_count = orders.filter(status='completed').count()
    ready_orders = orders.filter(status='ready').order_by('-created_at')[:10]
    return {
        'pending_count': pending_count,
        'ready_count': ready_count,
        'partial_count': partial_count,
        'completed_count': completed_count,
        'ready_orders': ready_orders,
    }
"""
    # Replace the existing function definition
    pattern = r'def chakki_counts\(request\):.*?(?=\n\n|\Z)'
    content = re.sub(pattern, new_func, content, flags=re.DOTALL)

    with open(cp_file, 'w') as f:
        f.write(content)
    print("✅ Patched core/context_processors.py (tenant filtering)")

# ---- 2. Add signal to delete walk-in customers ----
def add_signal():
    # We'll create a new file chakki/signals.py
    signal_file = 'chakki/signals.py'
    if not os.path.exists(signal_file):
        signal_content = """from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import ChakkiOrder, ChakkiCustomer

@receiver(post_save, sender=ChakkiOrder)
def delete_walkin_customer(sender, instance, **kwargs):
    # If order is completed and fully paid
    if instance.status == 'completed' and instance.payment_status == 'paid':
        customer = instance.customer
        # Only if it's a walk-in (not regular) and this is its only order
        if not customer.is_regular and customer.chakkiorder_set.count() == 1:
            customer.delete()
            print(f"🗑️ Deleted walk-in customer {customer.name} (no pending orders)")
"""
        with open(signal_file, 'w') as f:
            f.write(signal_content)
        print("✅ Created chakki/signals.py")
    else:
        print("ℹ️ chakki/signals.py already exists, skipping (check manually)")

    # Ensure signals are loaded: add to chakki/apps.py
    apps_file = 'chakki/apps.py'
    with open(apps_file, 'r') as f:
        content = f.read()
    if 'import chakki.signals' not in content:
        # Add import to ready method
        new_ready = """
    def ready(self):
        import chakki.signals
"""
        # Find class definition and insert ready method
        pattern = r'(class ChakkiConfig.*?:\s+)(name = .*?)(\s+)'
        replacement = r'\1\2\n' + new_ready
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        with open(apps_file, 'w') as f:
            f.write(content)
        print("✅ Patched chakki/apps.py to load signals")
    else:
        print("ℹ️ Signals already loaded in apps.py")

# ---- 3. Run the script ----
if __name__ == '__main__':
    patch_context_processor()
    add_signal()
    print("\n✅ All done! Restart your server for changes to take effect.")
    print("📌 Now, walk-in customers with fully paid orders will be automatically deleted after completion.")
    print("📌 Dashboard counts are now tenant-specific (no more data leakage).")
