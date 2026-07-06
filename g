#!/usr/bin/env python3
import os
import shutil
import sys
from datetime import datetime

# ---------- File paths (relative to current directory) ----------
FILES = {
    'tenants/models.py': 'tenants/models.py',
    'tenants/admin.py': 'tenants/admin.py',
    'core/views.py': 'core/views.py',
}

BACKUP_SUFFIX = '.bak.' + datetime.now().strftime('%Y%m%d_%H%M%S')

def backup_and_replace(filepath, new_content):
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return False
    backup = filepath + BACKUP_SUFFIX
    shutil.copy2(filepath, backup)
    print(f"✅ Backup created: {backup}")
    with open(filepath, 'w') as f:
        f.write(new_content)
    print(f"✅ Updated: {filepath}")
    return True

# ---------- 1. tenants/models.py ----------
models_new = '''from django.db import models
from django.conf import settings

class Tenant(models.Model):
    name = models.CharField(max_length=100)
    schema_name = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    category = models.CharField(max_length=20, default='chakki')
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)

    def __str__(self):
        return self.name
'''

# ---------- 2. tenants/admin.py ----------
admin_new = '''from django.contrib import admin
from django import forms
from django.contrib.auth import get_user_model
from .models import Tenant

User = get_user_model()

class TenantAdminForm(forms.ModelForm):
    admin_username = forms.CharField(max_length=150, required=True, label="Admin Username")
    admin_password = forms.CharField(
        widget=forms.PasswordInput,
        required=False,
        label="Admin Password (leave blank to keep current)"
    )

    class Meta:
        model = Tenant
        fields = ('name', 'schema_name', 'category')

    def save(self, commit=True):
        tenant = super().save(commit=False)
        username = self.cleaned_data['admin_username']
        password = self.cleaned_data.get('admin_password')

        # If tenant already has an owner, update that user
        if tenant.pk and tenant.owner:
            user = tenant.owner
            if user.username != username:
                user.username = username
                user.save()
            if password:
                user.set_password(password)
                user.save()
        else:
            # Create or get user
            user, created = User.objects.get_or_create(username=username)
            if created or password:
                user.set_password(password or User.objects.make_random_password())
                user.save()
            tenant.owner = user

        if commit:
            tenant.save()
        return tenant

@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    form = TenantAdminForm
    list_display = ('name', 'schema_name', 'category', 'owner', 'created_at')
    readonly_fields = ('created_at',)
    fields = ('name', 'schema_name', 'category', 'admin_username', 'admin_password', 'created_at')
'''

# ---------- 3. core/views.py (portal_login only) ----------
views_new = '''from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.http import Http404
from tenants.models import Tenant

def portal_login(request, schema_name):
    tenant = Tenant.objects.filter(schema_name=schema_name).first()
    if not tenant:
        raise Http404("Tenant not found")
    request.tenant = tenant
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)
        if user is not None:
            # Only owner or superuser can login to this tenant
            if user == tenant.owner or user.is_superuser:
                login(request, user)
                return redirect('portal_dashboard', schema_name=schema_name)
            else:
                return render(request, 'desktop/login.html', {'tenant': tenant, 'error': 'Access denied for this tenant'})
        else:
            return render(request, 'desktop/login.html', {'tenant': tenant, 'error': 'Invalid credentials'})
    return render(request, 'desktop/login.html', {'tenant': tenant})

def portal_logout(request, schema_name):
    logout(request)
    return redirect('portal_login', schema_name=schema_name)

def redirect_to_portal_login(request):
    next_url = request.GET.get('next', '')
    schema = None
    if next_url:
        parts = next_url.split('/')
        if len(parts) >= 3 and parts[1] == 'portal':
            schema = parts[2]
    if schema:
        from django.shortcuts import redirect
        return redirect(f'/portal/{schema}/?next={next_url}')
    else:
        from django.shortcuts import redirect
        return redirect('/admin/')

@login_required
def portal_dashboard(request, schema_name):
    tenant = Tenant.objects.filter(schema_name=schema_name).first()
    if not tenant:
        raise Http404("Tenant not found")
    if request.user != tenant.owner and not request.user.is_superuser:
        raise Http404("Access denied")
    request.tenant = tenant
    from chakki.views import dashboard as chakki_dashboard
    return chakki_dashboard(request)
'''

# ---------- Execute ----------
if __name__ == '__main__':
    print("🔧 Applying multi-tenant fix...")
    success = True
    success &= backup_and_replace(FILES['tenants/models.py'], models_new)
    success &= backup_and_replace(FILES['tenants/admin.py'], admin_new)
    success &= backup_and_replace(FILES['core/views.py'], views_new)

    if success:
        print("\n✅ All files updated successfully!")
        print("📌 Next steps:")
        print("  1. Restart your Django server (Railway will restart automatically).")
        print("  2. Now when you add/edit a tenant in admin, the username/password will be saved as the tenant's owner.")
        print("  3. Portal login will only work for that tenant's owner (or superuser).")
        print("  4. If you have existing tenants without an owner, edit each tenant in admin and set a username/password.")
    else:
        print("\n❌ Some files could not be updated. Check errors above.")
        sys.exit(1)
