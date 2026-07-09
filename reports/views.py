from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.db.models import Sum, Count, Q
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from chakki.models import ChakkiOrder, ChakkiCategory, SellingCategory, ChakkiCustomer, SellingOrderItem
from expenses.models import Expense

@login_required
def dashboard(request, **kwargs):
    tenant = request.tenant
    orders = ChakkiOrder.objects.filter(tenant=tenant)
    completed_orders = orders.filter(status='completed')
    pending_orders = orders.filter(status='pending')
    ready_orders = orders.filter(status='ready')

    total_revenue = completed_orders.aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
    total_pending = Decimal('0')
    for order in orders.exclude(status='completed'):
        total_pending += order.remaining_amount

    total_orders = orders.count()
    completed_count = completed_orders.count()

    # Revenue over last 30 days
    today = timezone.now().date()
    revenue_labels = []
    revenue_data = []
    for i in range(29, -1, -1):
        day = today - timedelta(days=i)
        revenue_labels.append(day.strftime('%d %b'))
        day_total = orders.filter(
            status='completed',
            created_at__date=day
        ).aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        revenue_data.append(float(day_total))

    # Order status counts
    status_data = {
        'Pending': orders.filter(status='pending').count(),
        'Ready': orders.filter(status='ready').count(),
        'Completed': orders.filter(status='completed').count(),
        'Cancelled': orders.filter(status='cancelled').count(),
    }

    # Recent orders
    recent_orders = orders.order_by('-created_at')[:10]

    context = {
        'total_revenue': total_revenue,
        'total_pending': total_pending,
        'total_orders': total_orders,
        'completed_count': completed_count,
        'revenue_labels': revenue_labels,
        'revenue_data': revenue_data,
        'status_data': status_data,
        'recent_orders': recent_orders,
        'tenant': tenant,
    }
    template = 'mobile/reports_dashboard.html' if request.mobile else 'desktop/reports_dashboard.html'
    return render(request, template, context)

@login_required
def revenue(request, **kwargs):
    tenant = request.tenant
    orders = ChakkiOrder.objects.filter(tenant=tenant, status='completed').order_by('-created_at')
    total_revenue = orders.aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
    # Group by date for chart
    today = timezone.now().date()
    revenue_by_day = {}
    for i in range(29, -1, -1):
        day = today - timedelta(days=i)
        day_total = orders.filter(created_at__date=day).aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        revenue_by_day[day.strftime('%d %b')] = float(day_total)

    context = {
        'orders': orders[:50],
        'total_revenue': total_revenue,
        'revenue_by_day': revenue_by_day,
        'tenant': tenant,
    }
    template = 'mobile/reports_revenue.html' if request.mobile else 'desktop/reports_revenue.html'
    return render(request, template, context)

@login_required
def categories(request, **kwargs):
    tenant = request.tenant
    grinding_cats = ChakkiCategory.objects.filter(tenant=tenant)
    selling_cats = SellingCategory.objects.filter(tenant=tenant)

    # Grinding categories
    for cat in grinding_cats:
        items = cat.chakkiorderitem_set.filter(tenant=tenant)
        cat.total_kg = items.aggregate(Sum('total_kg'))['total_kg__sum'] or Decimal('0')
        cat.total_revenue = items.aggregate(Sum('item_total'))['item_total__sum'] or Decimal('0')
        cat.total_orders = items.values('order').distinct().count()

    # Selling categories
    for cat in selling_cats:
        selling_items = SellingOrderItem.objects.filter(selling_price__category=cat, tenant=tenant)
        cat.total_qty = selling_items.aggregate(Sum('quantity'))['quantity__sum'] or Decimal('0')
        cat.total_revenue = selling_items.aggregate(Sum('total'))['total__sum'] or Decimal('0')
        cat.total_orders = selling_items.values('order').distinct().count()
        # profit
        total_cost = Decimal('0')
        for item in selling_items:
            total_cost += item.quantity * item.selling_price.purchase_price
        cat.total_profit = cat.total_revenue - total_cost

    context = {
        'grinding_categories': grinding_cats,
        'selling_categories': selling_cats,
        'tenant': tenant,
    }
    template = 'mobile/reports_categories.html' if request.mobile else 'desktop/reports_categories.html'
    return render(request, template, context)

@login_required
def customers(request, **kwargs):
    tenant = request.tenant
    customers = ChakkiCustomer.objects.filter(tenant=tenant)
    customer_data = []
    for c in customers:
        orders = ChakkiOrder.objects.filter(tenant=tenant, customer=c)
        total_spent = orders.filter(status='completed').aggregate(Sum('total_amount'))['total_amount__sum'] or Decimal('0')
        total_pending = Decimal('0')
        for order in orders.exclude(status='completed'):
            total_pending += order.remaining_amount
        order_count = orders.count()
        customer_data.append({
            'customer': c,
            'total_spent': total_spent,
            'total_pending': total_pending,
            'order_count': order_count,
        })
    customer_data.sort(key=lambda x: x['total_spent'], reverse=True)
    context = {
        'customer_data': customer_data[:50],
        'tenant': tenant,
    }
    template = 'mobile/reports_customers.html' if request.mobile else 'desktop/reports_customers.html'
    return render(request, template, context)

@login_required
def orders_report(request, **kwargs):
    tenant = request.tenant
    orders = ChakkiOrder.objects.filter(tenant=tenant).order_by('-created_at')
    # Status distribution
    status_dist = {
        'Pending': orders.filter(status='pending').count(),
        'Ready': orders.filter(status='ready').count(),
        'Completed': orders.filter(status='completed').count(),
        'Cancelled': orders.filter(status='cancelled').count(),
    }
    context = {
        'orders': orders[:50],
        'status_dist': status_dist,
        'tenant': tenant,
    }
    template = 'mobile/reports_orders.html' if request.mobile else 'desktop/reports_orders.html'
    return render(request, template, context)
