#!/usr/bin/env python3
"""
Fix subscription approve/reject URLs:
- Add tenant_id to URL patterns and views
- Update the global admin template to pass tenant_id
"""

import os
import re
from pathlib import Path

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')

import django
django.setup()

# ----------------------------------------------------------------------
# 1. Update saas_system/urls.py – add tenant_id to approve/reject paths
# ----------------------------------------------------------------------
urls_path = Path('saas_system/urls.py')
if urls_path.exists():
    with open(urls_path, 'r') as f:
        content = f.read()

    # Replace approve pattern
    content = re.sub(
        r"path\('admin/subscriptions/approve/<int:request_id>/',\s*subscription_views\.admin_approve_request,\s*name='admin_approve_request'\),",
        "path('admin/subscriptions/approve/<int:tenant_id>/<int:request_id>/', subscription_views.admin_approve_request, name='admin_approve_request'),",
        content
    )
    # Replace reject pattern
    content = re.sub(
        r"path\('admin/subscriptions/reject/<int:request_id>/',\s*subscription_views\.admin_reject_request,\s*name='admin_reject_request'\),",
        "path('admin/subscriptions/reject/<int:tenant_id>/<int:request_id>/', subscription_views.admin_reject_request, name='admin_reject_request'),",
        content
    )

    with open(urls_path, 'w') as f:
        f.write(content)
    print("✅ Updated saas_system/urls.py")
else:
    print("❌ saas_system/urls.py not found")

# ----------------------------------------------------------------------
# 2. Update subscriptions/views.py – accept tenant_id and switch schema
# ----------------------------------------------------------------------
views_path = Path('subscriptions/views.py')
if views_path.exists():
    with open(views_path, 'r') as f:
        content = f.read()

    # Replace the approve function signature and logic
    # Find the function definition and replace with corrected version
    # We'll locate the start of the function and replace everything until the next top-level def
    # We'll use a more robust approach: split by lines and replace the function block
    lines = content.splitlines()
    new_lines = []
    i = 0
    in_approve = False
    in_reject = False
    approve_skip = False
    reject_skip = False

    # We'll define the corrected functions as strings
    corrected_approve = """def admin_approve_request(request, tenant_id, request_id):
    if not request.user.is_superuser:
        messages.error(request, "Permission denied.")
        return redirect('global_subscription_review')

    tenant = get_object_or_404(Tenant, id=tenant_id)
    connection.set_tenant(tenant)
    req = get_object_or_404(SubscriptionRequest, id=request_id)
    req.refresh_from_db()
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
    return redirect('global_subscription_review')"""

    corrected_reject = """def admin_reject_request(request, tenant_id, request_id):
    if not request.user.is_superuser:
        messages.error(request, "Permission denied.")
        return redirect('global_subscription_review')

    tenant = get_object_or_404(Tenant, id=tenant_id)
    connection.set_tenant(tenant)
    req = get_object_or_404(SubscriptionRequest, id=request_id)
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
    return redirect('global_subscription_review')"""

    # We'll scan lines and skip the old functions, then insert our corrected versions
    # Keep track of when we are inside a function we want to replace
    inside_approve = False
    inside_reject = False
    skip_until_next_def = False
    for line in lines:
        # Detect start of admin_approve_request
        if line.strip().startswith('def admin_approve_request('):
            inside_approve = True
            # Add the corrected function
            new_lines.extend(corrected_approve.splitlines())
            skip_until_next_def = True
            continue
        # Detect start of admin_reject_request
        if line.strip().startswith('def admin_reject_request('):
            inside_reject = True
            # Add the corrected function
            new_lines.extend(corrected_reject.splitlines())
            skip_until_next_def = True
            continue
        # If we are inside a function we skipped, skip lines until we hit a top-level def or end
        if skip_until_next_def:
            # If line is not indented and is not a blank line, it might be a new top-level definition
            if line and not line[0].isspace():
                # This is a new top-level definition, stop skipping
                skip_until_next_def = False
                # But we already added our corrected function, so we should not add this line again
                # However, we need to keep this line (the next function) – but we already added our function,
                # so we continue without adding this line (it will be processed in next iterations)
                # But we must not skip it permanently; we'll set skip_until_next_def=False and continue
                # Actually, we want to keep all lines after the replaced functions.
                # So we should add this line now.
                new_lines.append(line)
            # If we are still skipping, do not add the line
            continue
        # If not skipping, add the line
        new_lines.append(line)

    # Write the new content
    with open(views_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print("✅ Updated subscriptions/views.py")
else:
    print("❌ subscriptions/views.py not found")

# ----------------------------------------------------------------------
# 3. Update templates/admin/review_subscriptions.html – use tenant_id in URL tags
# ----------------------------------------------------------------------
template_path = Path('templates/admin/review_subscriptions.html')
if template_path.exists():
    with open(template_path, 'r') as f:
        content = f.read()

    # Replace approve form action
    content = re.sub(
        r"action=\"{% url 'admin_approve_request' req\.id %}\"",
        "action=\"{% url 'admin_approve_request' tenant_id=req.tenant.id request_id=req.id %}\"",
        content
    )
    # Replace reject form action
    content = re.sub(
        r"action=\"{% url 'admin_reject_request' req\.id %}\"",
        "action=\"{% url 'admin_reject_request' tenant_id=req.tenant.id request_id=req.id %}\"",
        content
    )

    with open(template_path, 'w') as f:
        f.write(content)
    print("✅ Updated templates/admin/review_subscriptions.html")
else:
    print("❌ templates/admin/review_subscriptions.html not found – but that's OK if it doesn't exist.")

print("\n🎉 Fix applied! Restart your Django server and test the approve/reject buttons.")
