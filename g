#!/usr/bin/env python3
import os
import re
from pathlib import Path

# ----------------------------------------------------------------------
# Helper: add @login_required to view functions
# ----------------------------------------------------------------------
def add_login_required_to_file(filepath):
    """Add @login_required to all top-level view functions that lack it."""
    if not filepath.exists():
        print(f"⚠️  File not found: {filepath}")
        return

    with open(filepath, 'r') as f:
        lines = f.readlines()

    # Check if import exists
    import_line = "from django.contrib.auth.decorators import login_required\n"
    has_import = any("from django.contrib.auth.decorators import login_required" in line for line in lines)

    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Top-level function definition (not indented)
        if stripped.startswith('def ') and not line.startswith((' ', '\t')):
            # Look backward for existing decorators
            j = i - 1
            has_login_decorator = False
            while j >= 0 and (lines[j].strip().startswith('@') or lines[j].strip() == ''):
                if '@login_required' in lines[j] or '@staff_member_required' in lines[j] or '@permission_required' in lines[j]:
                    has_login_decorator = True
                    break
                j -= 1

            if not has_login_decorator:
                # Insert @login_required before the def
                new_lines.append('@login_required\n')

        new_lines.append(line)
        i += 1

    # Add import if missing (insert after the first import block or at top)
    if not has_import:
        # Find where to insert: after the last import line or after the module docstring
        insert_idx = 0
        for idx, line in enumerate(new_lines):
            if line.startswith('import ') or line.startswith('from '):
                insert_idx = idx + 1
            # Stop at first non-import, non-comment, non-blank
            if (line.strip() and not line.startswith(('import ', 'from ', '#', '\n'))) and insert_idx > 0:
                break
        new_lines.insert(insert_idx, import_line)

    with open(filepath, 'w') as f:
        f.writelines(new_lines)
    print(f"✅ Updated {filepath}")

# ----------------------------------------------------------------------
# Modify SubscriptionMiddleware
# ----------------------------------------------------------------------
def update_subscription_middleware():
    middleware_path = Path(__file__).parent / 'subscriptions' / 'middleware.py'
    if not middleware_path.exists():
        print(f"⚠️  {middleware_path} not found.")
        return

    with open(middleware_path, 'r') as f:
        content = f.read()

    # Ensure reverse import is present
    if 'from django.urls import reverse' not in content:
        # Insert after the existing imports
        lines = content.splitlines()
        insert_idx = 0
        for idx, line in enumerate(lines):
            if line.startswith('from ') or line.startswith('import '):
                insert_idx = idx + 1
        lines.insert(insert_idx, 'from django.urls import reverse')
        content = '\n'.join(lines)

    # Define the new process_view method
    new_process_view = '''
    def process_view(self, request, view_func, view_args, view_kwargs):
        if not request.tenant:
            return None

        tenant = request.tenant
        path = request.path_info

        # Exempt static/media/admin
        exempt_paths = [
            '/static/',
            '/media/',
            '/admin/',
            '/admin/subscriptions/review/',
        ]
        for exempt in exempt_paths:
            if path.startswith(exempt):
                return None

        # Exempt subscription URLs from subscription check (but still require login)
        if path.startswith('/portal/') and '/subscription/' in path:
            if not request.user.is_authenticated:
                login_url = reverse('portal_login', kwargs={'schema_name': tenant.schema_name})
                return HttpResponseRedirect(f'{login_url}?next={path}')
            return None  # allow access (payment/upload/processing)

        # Exempt the login page itself
        portal_root = f'/portal/{tenant.schema_name}/'
        if path == portal_root or path == portal_root.rstrip('/'):
            return None

        # Check authentication
        if not request.user.is_authenticated:
            login_url = reverse('portal_login', kwargs={'schema_name': tenant.schema_name})
            return HttpResponseRedirect(f'{login_url}?next={path}')

        # Now check subscription
        if not tenant.is_subscription_active():
            from .models import SubscriptionRequest
            pending_req = SubscriptionRequest.objects.filter(tenant=tenant, status='pending').first()
            if pending_req:
                processing_url = reverse('subscriptions:subscription_processing', kwargs={'schema_name': tenant.schema_name})
                return HttpResponseRedirect(processing_url)
            else:
                payment_url = reverse('subscriptions:subscription_payment', kwargs={'schema_name': tenant.schema_name})
                return HttpResponseRedirect(payment_url)

        return None
'''

    # Replace the old process_view with the new one
    # We'll find the existing method and replace its body
    pattern = r'(def process_view\(self, request, view_func, view_args, view_kwargs\):.*?)(?=\n\s+def|\nclass|\Z)'
    replacement = new_process_view
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

    if new_content == content:
        print("⚠️  Could not update middleware.py. Please update manually.")
    else:
        with open(middleware_path, 'w') as f:
            f.write(new_content)
        print("✅ Updated subscriptions/middleware.py")

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main():
    print("🚀 Patcher: Adding login_required to all views and fixing subscription middleware")

    # 1. Add login_required to all views in chakki, expenses, reports, subscriptions
    apps = ['chakki', 'expenses', 'reports', 'subscriptions']
    for app in apps:
        views_file = Path(__file__).parent / app / 'views.py'
        if views_file.exists():
            add_login_required_to_file(views_file)
        else:
            print(f"⚠️  No views.py in {app}")

    # 2. Update subscription middleware
    update_subscription_middleware()

    print("\n✅ Patcher completed.")
    print("📌 Please restart the server (e.g., sudo systemctl restart gunicorn) to apply changes.")
    print("📌 Test: try accessing /portal/<schema>/dashboard while logged out – you should be redirected to login.")
    print("📌 After login, if subscription is inactive, you'll be redirected to payment page.")

if __name__ == '__main__':
    main()
