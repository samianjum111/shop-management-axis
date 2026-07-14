from django.shortcuts import render, redirect, get_object_or_404
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

def root_redirect(request):
    if request.user.is_authenticated:
        from tenants.models import Tenant
        # Try to get the last visited tenant from session
        last_schema = request.session.get('last_tenant_schema')
        tenant = None
        if last_schema:
            tenant = Tenant.objects.filter(schema_name=last_schema).first()
        if not tenant:
            # Fallback to first owned tenant
            tenant = Tenant.objects.filter(owner=request.user).first()
        if tenant:
            return redirect('portal_dashboard', schema_name=tenant.schema_name)
        elif request.user.is_superuser:
            return redirect('/admin/')
        else:
            return redirect('login')
    else:
        return render(request, 'root_home.html')
@login_required
def more_view(request, schema_name):
    from tenants.models import Tenant
    tenant = get_object_or_404(Tenant, schema_name=schema_name)
    request.tenant = tenant
    context = {'tenant': tenant}
    template = 'mobile/more.html' if request.mobile else 'desktop/more.html'
    return render(request, template, context)

@login_required
def customers_view(request, schema_name):
    return redirect('customer_list', schema_name=schema_name)