from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.http import Http404
from tenants.models import Tenant

def portal_login(request, schema_name):
    tenant = get_object_or_404(Tenant, schema_name=schema_name)
    request.tenant = tenant   # context processor ke liye
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        # authenticate against tenant DB
        user = authenticate(request, username=username, password=password)
        if user is not None:
            login(request, user)
            return redirect('portal_dashboard', schema_name=schema_name)
        else:
            return render(request, 'desktop/login.html', {'tenant': tenant, 'error': 'Invalid credentials'})
    return render(request, 'desktop/login.html', {'tenant': tenant})

def portal_logout(request, schema_name):
    logout(request)
    return redirect('portal_login', schema_name=schema_name)

@login_required
def portal_dashboard(request, schema_name):
    tenant = get_object_or_404(Tenant, schema_name=schema_name)
    if request.user != tenant.owner and not request.user.is_superuser:
        # Agar tenant owner nahi hai to access deny
        raise Http404("Access denied")
    request.tenant = tenant
    # yahan chakki ka dashboard render karein
    from chakki.views import dashboard as chakki_dashboard
    return chakki_dashboard(request)
