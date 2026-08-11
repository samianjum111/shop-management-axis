#!/usr/bin/env python3
"""
Patch subscriptions/views.py, urls.py, and admin template to fix approve/reject URLs.
Run with: python3 patch_admin_urls.py
"""

import os
import sys
import re
from pathlib import Path

# Set Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
import django
django.setup()

from django.conf import settings
from django.core.management import call_command

VIEWS_PATH = Path(__file__).parent / 'subscriptions' / 'views.py'
URLS_PATH = Path(__file__).parent / 'saas_system' / 'urls.py'
TEMPLATE_PATH = Path(__file__).parent / 'templates' / 'admin' / 'review_subscriptions.html'

def add_admin_views():
    """Add admin_approve_request and admin_reject_request to views.py."""
    if not VIEWS_PATH.exists():
        print("❌ subscriptions/views.py not found.")
        return False

    with open(VIEWS_PATH, 'r') as f:
        content = f.read()

    # Check if already present
    if 'def admin_approve_request' in content:
        print("✅ Admin approve/reject views already exist.")
        return True

    # Insert new functions after the existing reject_request function
    new_views = """

# ---------- Admin-only approve/reject (no schema_name needed) ----------
@staff_member_required
def admin_approve_request(request, request_id):
    if not request.user.is_superuser:
        messages.error(request, "Permission denied.")
        return redirect('global_subscription_review')

    # Switch to tenant's schema to get the request
    req = get_object_or_404(SubscriptionRequest, id=request_id)
    tenant = req.tenant
    connection.set_tenant(tenant)
    req.refresh_from_db()  # now in tenant schema
    if req.status != 'pending':
        messages.warning(request, "This request has already been processed.")
        connection.set_schema_to_public()
        return redirect('global_subscription_review')

    with transaction.atomic():
        req.status = 'approved'
        req.processed_at = timezone.now()
        req.save()
        if tenant.subscription_duration_days:
            tenant.subscription_end_date = timezone.now() + timedelta(days=tenant.subscription_duration_days)
            tenant.save()
        else:
            messages.warning(request, f"Tenant {tenant.name} has no duration set. Subscription not extended.")
    connection.set_schema_to_public()
    messages.success(request, f"Subscription for {tenant.name} approved and extended.")
    return redirect('global_subscription_review')

@staff_member_required
def admin_reject_request(request, request_id):
    if not request.user.is_superuser:
        messages.error(request, "Permission denied.")
        return redirect('global_subscription_review')

    req = get_object_or_404(SubscriptionRequest, id=request_id)
    tenant = req.tenant
    connection.set_tenant(tenant)
    req.refresh_from_db()
    if req.status != 'pending':
        messages.warning(request, "This request has already been processed.")
        connection.set_schema_to_public()
        return redirect('global_subscription_review')

    req.status = 'rejected'
    req.processed_at = timezone.now()
    req.save()
    connection.set_schema_to_public()
    messages.success(request, f"Subscription request for {tenant.name} rejected.")
    return redirect('global_subscription_review')
"""

    # Find the last function definition (or end of file)
    lines = content.splitlines()
    # Insert after the last line that is not a decorator or blank
    # We'll place it after the existing reject_request function.
    # Find the last occurrence of "def reject_request" and insert after its body.
    # Simpler: append at the end of the file.
    new_content = content + new_views
    with open(VIEWS_PATH, 'w') as f:
        f.write(new_content)
    print("✅ Added admin approve/reject views.")
    return True

def add_admin_urls():
    """Add admin-specific approve/reject URLs to saas_system/urls.py."""
    if not URLS_PATH.exists():
        print("❌ saas_system/urls.py not found.")
        return False

    with open(URLS_PATH, 'r') as f:
        content = f.read()

    # Check if already present
    if "admin/subscriptions/approve/" in content:
        print("✅ Admin approve/reject URLs already exist.")
        return True

    # Add import if missing
    if 'from subscriptions import views as subscription_views' not in content:
        # Add after existing imports
        import_line = "from subscriptions import views as subscription_views"
        lines = content.splitlines()
        insert_idx = 0
        for i, line in enumerate(lines):
            if line.startswith('from ') or line.startswith('import '):
                insert_idx = i + 1
        lines.insert(insert_idx, import_line)
        content = '\n'.join(lines)

    # Add URL patterns
    # Find urlpatterns list and insert new paths after the existing admin/subscriptions/review/ path
    pattern = r"(urlpatterns\s*=\s*\[[\s\S]*?)(\n\])"
    replacement = r"""\1
    path('admin/subscriptions/approve/<int:request_id>/', subscription_views.admin_approve_request, name='admin_approve_request'),
    path('admin/subscriptions/reject/<int:request_id>/', subscription_views.admin_reject_request, name='admin_reject_request'),
]"""
    new_content = re.sub(pattern, replacement, content, count=1)

    if new_content == content:
        print("⚠️  Could not automatically add URLs. Please add them manually.")
        return False

    with open(URLS_PATH, 'w') as f:
        f.write(new_content)
    print("✅ Added admin approve/reject URLs.")
    return True

def update_template():
    """Update admin template to use new URLs."""
    if not TEMPLATE_PATH.exists():
        print("❌ admin/review_subscriptions.html not found.")
        return False

    with open(TEMPLATE_PATH, 'r') as f:
        content = f.read()

    # Replace old URLs with new ones
    # We'll replace the action URLs in the form tags.
    # Forms currently use:
    #   {% url 'subscriptions:approve_request' req.id %}
    #   {% url 'subscriptions:reject_request' req.id %}
    # Replace with:
    #   {% url 'admin_approve_request' req.id %}
    #   {% url 'admin_reject_request' req.id %}
    new_content = content.replace("{% url 'subscriptions:approve_request' req.id %}", "{% url 'admin_approve_request' req.id %}")
    new_content = new_content.replace("{% url 'subscriptions:reject_request' req.id %}", "{% url 'admin_reject_request' req.id %}")

    if new_content == content:
        print("⚠️  No changes made to template (maybe already updated).")
    else:
        with open(TEMPLATE_PATH, 'w') as f:
            f.write(new_content)
        print("✅ Updated admin template to use new URLs.")
    return True

def main():
    print("🔧 Patching admin approve/reject URLs...")
    views_ok = add_admin_views()
    urls_ok = add_admin_urls()
    template_ok = update_template()

    if views_ok and urls_ok and template_ok:
        print("\n🎉 Done! Please restart your Django server.")
        print("   Visit /admin/subscriptions/review/ and try Approve/Reject now.")
    else:
        print("\n⚠️  Some steps failed. Please review errors above.")

if __name__ == "__main__":
    main()
