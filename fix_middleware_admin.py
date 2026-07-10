import os

MIDDLEWARE_PATH = "core/middleware.py"

with open(MIDDLEWARE_PATH, 'r') as f:
    content = f.read()

# Replace the else block to always set tenant for admin
new_content = content.replace(
    "else:\n                # For admin and other non-portal paths, use public tenant\n                tenant = Tenant.objects.get(schema_name='public')\n                request.tenant = tenant\n                connection.set_tenant(tenant)",
    """else:
                # For admin and other non-portal paths, use public tenant
                try:
                    tenant = Tenant.objects.get(schema_name='public')
                    request.tenant = tenant
                    connection.set_tenant(tenant)
                except Tenant.DoesNotExist:
                    request.tenant = None
                    connection.set_schema_to_public()"""
)

with open(MIDDLEWARE_PATH, 'w') as f:
    f.write(new_content)

print("✅ Updated middleware to handle missing public tenant.")
