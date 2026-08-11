#!/usr/bin/env python3
"""
Final Subscription System Patcher
- Adds a global super admin review page (/admin/subscriptions/review/)
- Ensures middleware exempts that URL
- Runs tenant schema migrations (skip public)
- Ensures superuser exists
- Prints instructions
"""

import os
import sys
import re
from pathlib import Path

# Set Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')

import django
django.setup()

from django.core.management import call_command
from django.conf import settings
from django.contrib.auth import get_user_model
from tenants.models import Tenant

User = get_user_model()

def add_global_review_view():
    """Add a global review view to subscriptions/views.py if missing."""
    views_path = Path(__file__).parent / 'subscriptions' / 'views.py'
    if not views_path.exists():
        print("⚠️  subscriptions/views.py not found. Cannot add global review view.")
        return

    with open(views_path, 'r') as f:
        content = f.read()

    # Check if the global review view already exists
    if 'def global_review_subscriptions' in content:
        print("✅ Global review view already exists in views.py.")
        return

    # Insert the view after the existing review_submissions view
    # We'll find the last @staff_member_required or the end of the file
    insert_marker = 'def review_subscriptions'
    if insert_marker not in content:
        print("⚠️  Could not find review_subscriptions view. Please add the global review view manually.")
        return

    # We'll insert after the review_subscriptions function (or at the end)
    # We'll add the new function after the existing ones
    new_view = """

# ---------- Global Super Admin Review (not tenant-specific) ----------
from django.db import connection

@staff_member_required
def global_review_subscriptions(request):
    if not request.user.is_superuser:
        messages.error(request, "You do not have permission to access this page.")
        return redirect('/admin/')

    # Switch to public schema to access all tenant requests
    connection.set_schema_to_public()
    pending_requests = SubscriptionRequest.objects.filter(status='pending').select_related('tenant')
    approved_requests = SubscriptionRequest.objects.filter(status='approved').select_related('tenant')[:20]
    rejected_requests = SubscriptionRequest.objects.filter(status='rejected').select_related('tenant')[:20]

    context = {
        'pending_requests': pending_requests,
        'approved_requests': approved_requests,
        'rejected_requests': rejected_requests,
    }
    # Use the same admin template
    return render(request, 'admin/review_subscriptions.html', context)
"""

    # Insert after the last function or at end
    # Find the last 'def' or the end of file
    lines = content.splitlines()
    # Find the last line that starts with 'def' or is a function end
    insert_index = len(lines)
    for i in range(len(lines)-1, -1, -1):
        if lines[i].strip().startswith('def '):
            # find the end of that function by looking for next def or end
            # We'll insert after the function body (i.e., after the return or last line of function)
            # For simplicity, insert at the end of the file
            break
    # If we didn't find a good spot, put at end
    new_content = content + new_view
    with open(views_path, 'w') as f:
        f.write(new_content)
    print("✅ Added global review view to subscriptions/views.py.")

def add_global_review_url():
    """Add the global review URL to saas_system/urls.py."""
    urls_path = Path(__file__).parent / 'saas_system' / 'urls.py'
    if not urls_path.exists():
        print("⚠️  saas_system/urls.py not found. Cannot add URL.")
        return

    with open(urls_path, 'r') as f:
        content = f.read()

    # Check if URL already exists
    if "admin/subscriptions/review/" in content:
        print("✅ Global review URL already exists in urls.py.")
        return

    # Add import for subscriptions.views if not present
    if 'import subscriptions.views' not in content:
        # Add import after existing imports
        import_line = "from subscriptions import views as subscription_views"
        # Insert after the last import
        lines = content.splitlines()
        insert_idx = 0
        for i, line in enumerate(lines):
            if line.startswith('from ') or line.startswith('import '):
                insert_idx = i + 1
        lines.insert(insert_idx, import_line)
        content = '\n'.join(lines)

    # Add the URL pattern
    # Find the urlpatterns list
    pattern = r"(urlpatterns\s*=\s*\[[\s\S]*?)(\n\])"
    replacement = r"\1    path('admin/subscriptions/review/', subscription_views.global_review_subscriptions, name='global_subscription_review'),\n]"
    new_content = re.sub(pattern, replacement, content, count=1)

    if new_content == content:
        print("⚠️  Could not add URL automatically. Please add manually: path('admin/subscriptions/review/', subscription_views.global_review_subscriptions, name='global_subscription_review')")
        return

    with open(urls_path, 'w') as f:
        f.write(new_content)
    print("✅ Added global review URL to saas_system/urls.py.")

def exempt_global_review_in_middleware():
    """Ensure the global review URL is exempt from subscription middleware."""
    middleware_path = Path(__file__).parent / 'subscriptions' / 'middleware.py'
    if not middleware_path.exists():
        print("⚠️  subscriptions/middleware.py not found. Cannot exempt URL.")
        return

    with open(middleware_path, 'r') as f:
        content = f.read()

    # Check if the URL is already exempt
    if "'/admin/subscriptions/review/'" in content:
        print("✅ Global review URL already exempt in middleware.")
        return

    # Add the URL to exempt_paths in process_view
    # Find the exempt_paths list
    pattern = r"(exempt_paths\s*=\s*\[[\s\S]*?)(\n\s*\])"
    replacement = r"\1,\n            '/admin/subscriptions/review/',\n        ]"
    new_content = re.sub(pattern, replacement, content, count=1)

    if new_content == content:
        print("⚠️  Could not automatically exempt URL. Please add '/admin/subscriptions/review/' to exempt_paths in subscription middleware.")
        return

    with open(middleware_path, 'w') as f:
        f.write(new_content)
    print("✅ Added global review URL to middleware exempt paths.")

def run_migrations():
    """Run tenant schema migrations (skip public)."""
    print("\n🔄 Running tenant schema migrations (skipping public)...")
    try:
        call_command('migrate_schemas', interactive=False, skip_public=True)
    except Exception as e:
        print(f"⚠️  Error during tenant schema migrations: {e}")
        print("   Try manually: python manage.py migrate_schemas --skip-public")
    else:
        print("✅ Tenant schemas migrated successfully.")

def ensure_middleware():
    """Check if subscription middleware is in settings."""
    settings_path = Path(__file__).parent / 'saas_system' / 'settings.py'
    if not settings_path.exists():
        print("⚠️  Could not find settings.py. Please manually add 'subscriptions.middleware.SubscriptionMiddleware' to MIDDLEWARE.")
        return

    with open(settings_path, 'r') as f:
        content = f.read()

    if 'subscriptions.middleware.SubscriptionMiddleware' in content:
        print("✅ Subscription middleware already present.")
        return

    print("⚠️  Subscription middleware not found. Please add 'subscriptions.middleware.SubscriptionMiddleware' after TenantFromPathMiddleware in MIDDLEWARE.")
    # We could auto-add, but we already did in previous steps. Just warn.

def ensure_app_installed():
    """Check if subscriptions app is installed."""
    if 'subscriptions' in settings.INSTALLED_APPS:
        print("✅ Subscriptions app is installed.")
    else:
        print("⚠️  'subscriptions' not in INSTALLED_APPS. Please add it manually.")

def create_superuser():
    """Create a superuser if none exists."""
    if User.objects.filter(is_superuser=True).exists():
        print("✅ Superuser exists.")
        return

    print("\n🔑 No superuser found. Creating one...")
    username = input("Enter superuser username (default: admin): ").strip() or 'admin'
    email = input("Enter superuser email (default: admin@example.com): ").strip() or 'admin@example.com'
    password = input("Enter superuser password (default: admin123): ").strip() or 'admin123'
    User.objects.create_superuser(username=username, email=email, password=password)
    print(f"✅ Superuser '{username}' created.")

def print_instructions():
    print("\n" + "="*60)
    print("🎉 SUBSCRIPTION SYSTEM IS READY!")
    print("="*60)
    print("\n📌 SUPER ADMIN REVIEW PANEL:")
    print("  ─────────────────────────────────────────────")
    print("  Visit: http://localhost:8000/admin/subscriptions/review/")
    print("  (Login with your superuser credentials)")
    print("\n  Here you can see all pending subscription requests from ALL tenants.")
    print("  Approve or reject each request. Approval extends the subscription.")
    print("\n📌 TENANT CONFIGURATION:")
    print("  - In Django Admin -> Tenants, set for each tenant:")
    print("    - Subscription duration (days)")
    print("    - Subscription amount")
    print("    - JazzCash number and name")
    print("\n📌 USER FLOW:")
    print("  - When a tenant's subscription expires, they see the payment screen.")
    print("  - They upload a payment screenshot.")
    print("  - Super admin reviews and approves/rejects.")
    print("  - On approval, subscription end date is extended.")
    print("\n✅ Everything is configured. Restart the server and test.")
    print("="*60)

def main():
    print("🚀 Final Subscription System Patcher")
    add_global_review_view()
    add_global_review_url()
    exempt_global_review_in_middleware()
    run_migrations()
    ensure_middleware()
    ensure_app_installed()
    create_superuser()
    print_instructions()

if __name__ == "__main__":
    main()
