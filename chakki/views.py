from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from decimal import Decimal
from .models import ChakkiCustomer, ChakkiOrder, ChakkiSetting

@login_required
def dashboard(request):
    tenant = request.tenant
    pending = ChakkiOrder.objects.filter(status='pending')
    ready = ChakkiOrder.objects.filter(status='ready')
    completed = ChakkiOrder.objects.filter(status='completed')
    # auto ready check
    for order in pending:
        if order.ready_time and order.ready_time <= timezone.now():
            order.status = 'ready'
            order.save()
            messages.info(request, f"Order #{order.id} ready!")
    recent = ChakkiOrder.objects.order_by('-created_at')[:10]
    context = {
        'pending': pending.count(),
        'ready': ready.count(),
        'completed': completed.count(),
        'recent_orders': recent,
        'customers': ChakkiCustomer.objects.all(),
        'tenant': tenant,
    }
    template = 'mobile/chakki_dashboard.html' if request.mobile else 'desktop/chakki_dashboard.html'
    return render(request, template, context)

@login_required
def add_order(request):
    if request.method == 'POST':
        customer_id = request.POST.get('customer')
        if customer_id == 'new':
            cust = ChakkiCustomer.objects.create(
                name=request.POST.get('name'),
                phone=request.POST.get('phone'),
                address=request.POST.get('address')
            )
        else:
            cust = get_object_or_404(ChakkiCustomer, id=customer_id)
        total_kg = Decimal(request.POST.get('total_kg'))
        cleaning = request.POST.get('cleaning') == 'on'
        time_type = request.POST.get('time_type')
        time_value = int(request.POST.get('time_value', 0))
        ready_time = timezone.now()
        if time_type == 'minutes':
            ready_time += timezone.timedelta(minutes=time_value)
        elif time_type == 'hours':
            ready_time += timezone.timedelta(hours=time_value)
        elif time_type == 'days':
            ready_time += timezone.timedelta(days=time_value)
        order = ChakkiOrder.objects.create(
            customer=cust,
            total_kg=total_kg,
            is_cleaning_done=cleaning,
            ready_time=ready_time,
            status='pending'
        )
        messages.success(request, f"Order #{order.id} created! Ready at {ready_time.strftime('%I:%M %p')}")
        return redirect('chakki_dashboard')
    customers = ChakkiCustomer.objects.all()
    template = 'mobile/add_order.html' if request.mobile else 'desktop/add_order.html'
    return render(request, template, {'customers': customers})

@login_required
def complete_order(request, order_id):
    order = get_object_or_404(ChakkiOrder, id=order_id)
    if order.status != 'completed':
        order.status = 'completed'
        order.completed_at = timezone.now()
        order.save()
        messages.success(request, f"Order #{order.id} Completed!")
    return redirect('chakki_dashboard')

@login_required
def settings_view(request):
    setting, _ = ChakkiSetting.objects.get_or_create(id=1)
    if request.method == 'POST':
        setting.grinding_rate = Decimal(request.POST.get('grinding_rate'))
        setting.cleaning_rate = Decimal(request.POST.get('cleaning_rate'))
        setting.save()
        messages.success(request, "Rates updated!")
        return redirect('chakki_dashboard')
    template = 'mobile/settings.html' if request.mobile else 'desktop/settings.html'
    return render(request, template, {'setting': setting})
