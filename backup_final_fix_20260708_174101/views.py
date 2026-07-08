from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from django.db.models import Q
from decimal import Decimal
from django.http import JsonResponse
from django.template.loader import render_to_string
from .models import ChakkiCustomer, ChakkiOrder, ChakkiSetting, ChakkiCategory, ChakkiOrderItem, SellingCategory, SellingPrice, SellingOrderItem

from expenses.models import Expense


@login_required
def chakki_home(request, **kwargs):
    from django.core.paginator import Paginator
    from django.db.models import Q

    tenant = request.tenant
    orders = ChakkiOrder.objects.filter(tenant=request.tenant).exclude(status='cancelled').order_by('-created_at')

    status_filter = request.GET.get('status', 'all')
    if status_filter == 'pending':
        orders = orders.filter(status='pending')
    elif status_filter == 'ready':
        orders = orders.filter(status='ready')
    elif status_filter == 'partial':
        orders = orders.filter(payment_status='partial')
    elif status_filter == 'completed':
        orders = orders.filter(status='completed')
    else:
        status_filter = 'all'

    search_q = request.GET.get('search', '').strip()
    if search_q:
        orders = orders.filter(
            Q(customer__name__icontains=search_q) |
            Q(customer__phone__icontains=search_q) |
            Q(id__icontains=search_q)
        )

    all_count = orders.count()
    pending_count = orders.filter(status='pending').count()
    ready_count = orders.filter(status='ready').count()
    partial_count = orders.filter(payment_status='partial').count()
    completed_count = orders.filter(status='completed').count()

    paginator = Paginator(orders, 30)
    page_number = request.GET.get('page', 1)
    try:
        page_obj = paginator.page(page_number)
    except:
        page_obj = paginator.page(1)

    context = {
        'page_obj': page_obj,
        'status_filter': status_filter,
        'search_q': search_q,
        'tenant': tenant,
        'all_count': all_count,
        'pending_count': pending_count,
        'ready_count': ready_count,
        'partial_count': partial_count,
        'completed_count': completed_count,,
        "cancelled_count": cancelled_count,}

    # ---- Added by patcher: chart & revenue stats ----
    from django.db.models import Sum
    from django.utils import timezone
    from datetime import timedelta

    # Total revenue
    total_revenue = orders.aggregate(Sum('total_amount'))['total_amount__sum'] or 0

    # Daily order counts for last 7 days
    today = timezone.now().date()
    daily_labels = []
    daily_counts = []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        daily_labels.append(day.strftime('%a'))
        count = ChakkiOrder.objects.filter(tenant=request.tenant, created_at__date=day).count()
        daily_counts.append(count)

    # Add to context
    context['total_revenue'] = total_revenue
    context['daily_labels'] = daily_labels
    context['daily_counts'] = daily_counts
    # -------------------------------------------------
    template = 'mobile/chakki.html' if request.mobile else 'desktop/chakki.html'
    return render(request, template, context)


@login_required
def dashboard(request, **kwargs):
    tenant = request.tenant
    pending_orders = ChakkiOrder.objects.filter(tenant=request.tenant, status='pending',)
    for order in pending_orders:
        if order.ready_time and order.ready_time <= timezone.now():
            order.status = 'ready'
            order.save()
            messages.info(request, f"Order #{order.id} for {order.customer.name} is READY!")

    orders = ChakkiOrder.objects.filter(tenant=request.tenant)
    pending = orders.filter(status='pending')
    ready = orders.filter(status='ready')
    completed = orders.filter(status='completed')
    partial_orders = orders.filter(payment_status='partial')

    pending_count = pending.count()
    ready_count = ready.count()
    partial_count = partial_orders.count()
    completed_count = completed.count()
    ready_orders = ready.order_by('-created_at')[:10]

    expenses = Expense.objects.filter(tenant=request.tenant)
    total_expenses = sum(e.amount for e in expenses)
    total_given = sum(e.amount for e in expenses if e.is_credit and not e.is_repaid)
    total_taken = sum(e.amount for e in expenses if e.category == 'taken_loan' and not e.is_repaid)
    total_income = sum(o.total_amount for o in completed if o.payment_status == 'paid')
    net_profit = total_income - total_expenses

    recent_orders = orders.order_by('-created_at')[:10]
    context = {
        'pending': pending_count,
        'ready': ready_count,
        'completed': completed_count,
        'partial': partial_count,
        'pending_count': pending_count,
        'ready_count': ready_count,
        'partial_count': partial_count,
        'completed_count': completed_count,
        'ready_orders': ready_orders,
        'total_income': total_income,
        'total_expenses': total_expenses,
        'net_profit': net_profit,
        'total_pending_value': sum(o.total_amount for o in pending),
        'total_given': total_given,
        'total_taken': total_taken,
        'recent_orders': recent_orders,
        'tenant': tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/chakki_dashboard.html' if request.mobile else 'desktop/chakki_dashboard.html'
    return render(request, template, context)


@login_required
def calculate_order(request, **kwargs):
    if request.method == 'POST':
        total_kg = Decimal(request.POST.get('total_kg', 0))
        cleaning = request.POST.get('cleaning') == 'true'
        setting, _ = ChakkiSetting.objects.get_or_create(tenant=request.tenant)
        grinding_charges = total_kg * setting.grinding_rate
        cleaning_charges = total_kg * setting.cleaning_rate if cleaning else 0
        total_amount = grinding_charges + cleaning_charges
        return JsonResponse({
            'grinding_charges': float(grinding_charges),
            'cleaning_charges': float(cleaning_charges),
            'total_amount': float(total_amount)
        })
    return JsonResponse({'error': 'Invalid request'}, status=400)


@login_required
def order_list(request, order_type, **kwargs):
    tenant = request.tenant
    orders = ChakkiOrder.objects.filter(tenant=request.tenant)
    if order_type == 'pending':
        orders = orders.filter(status='pending')
    elif order_type == 'ready':
        orders = orders.filter(status='ready').exclude(payment_status='partial')
    elif order_type == 'partial':
        orders = orders.filter(payment_status='partial')
    elif order_type == 'completed':
        orders = orders.filter(status='completed')
    else:
        orders = orders.all()

    search = request.GET.get('search', '')
    if search:
        orders = orders.filter(
            Q(customer__name__icontains=search) |
            Q(customer__phone__icontains=search) |
            Q(id__icontains=search)
        )

    context = {
        'orders': orders.order_by('-created_at'),
        'order_type': order_type,
        'tenant': tenant,,
        "cancelled_count": cancelled_count,}
    template = f'mobile/order_list.html' if request.mobile else f'desktop/order_list.html'
    return render(request, template, context)


@login_required

def order_detail(request, order_id, **kwargs):
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    if order.status == 'completed':
        return redirect('generate_transcript', schema_name=request.tenant.schema_name, order_id=order.id)

    if request.method == 'POST' and 'payment_amount' in request.POST:
        amount = Decimal(request.POST.get('payment_amount', 0))
        if amount > 0:
            order.amount_paid += amount
            if order.amount_paid > order.total_amount:
                order.amount_paid = order.total_amount
            if order.amount_paid >= order.total_amount and order.total_amount > 0:
                order.status = 'completed'
                order.completed_at = timezone.now()
            order.save()
            messages.success(request, f"Payment of ₹{amount} added. Remaining: ₹{order.remaining_amount}")
        return redirect('order_detail', schema_name=request.tenant.schema_name, order_id=order.id)

    items = order.items.all()
    selling_items = order.selling_items.all()
    context = {
        'order': order,
        'items': items,
        'selling_items': selling_items,
        'tenant': request.tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/order_detail.html' if request.mobile else 'desktop/order_detail.html'
    return render(request, template, context)

def complete_order(request, order_id, **kwargs):
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    if order.remaining_amount > 0:
        messages.error(request, "Order cannot be completed until full payment is received.")
        return redirect('order_detail', schema_name=request.tenant.schema_name, order_id=order.id)
    if order.status != 'completed':
        order.status = 'completed'
        order.completed_at = timezone.now()
        order.save()
        messages.success(request, f"Order #{order.id} Completed!")
    return redirect('portal_dashboard', schema_name=request.tenant.schema_name)


@login_required
def generate_transcript(request, order_id, **kwargs):
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    context = {'order': order, 'tenant': request.tenant,
        "cancelled_count": cancelled_count,}
    return render(request, 'desktop/transcript.html', context)


@login_required

@login_required

@login_required

@login_required
def settings_view(request, **kwargs):
    # No global rates anymore; we use per-category rates.
    categories = ChakkiCategory.objects.filter(tenant=request.tenant)
    selling_categories = SellingCategory.objects.filter(tenant=request.tenant).prefetch_related('prices')

    if request.method == 'POST':
        action = request.POST.get('action')
        # ----- Grinding Categories -----
        if action == 'add_category':
            name = request.POST.get('category_name')
            desc = request.POST.get('category_description', '')
            grinding_rate = request.POST.get('grinding_rate')
            cleaning_rate = request.POST.get('cleaning_rate') or None
            if name and grinding_rate:
                ChakkiCategory.objects.create(
                    tenant=request.tenant,
                    name=name,
                    description=desc,
                    grinding_rate=grinding_rate,
                    cleaning_rate=cleaning_rate
                )
                messages.success(request, f"Category '{name}' added.")
            else:
                messages.error(request, "Category name and grinding rate are required.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        elif action == 'edit_category':
            cat_id = request.POST.get('category_id')
            name = request.POST.get('category_name')
            desc = request.POST.get('category_description', '')
            grinding_rate = request.POST.get('grinding_rate')
            cleaning_rate = request.POST.get('cleaning_rate') or None
            if cat_id and name and grinding_rate:
                category = get_object_or_404(ChakkiCategory, id=cat_id, tenant=request.tenant)
                category.name = name
                category.description = desc
                category.grinding_rate = grinding_rate
                category.cleaning_rate = cleaning_rate
                category.save()
                messages.success(request, f"Category '{name}' updated.")
            else:
                messages.error(request, "All fields are required.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        elif action == 'delete_category':
            cat_id = request.POST.get('category_id')
            if cat_id:
                category = get_object_or_404(ChakkiCategory, id=cat_id, tenant=request.tenant)
                category.delete()
                messages.success(request, "Category deleted.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        # ----- Selling Categories with Price -----
        elif action == 'add_selling_category_with_price':
            name = request.POST.get('selling_category_name')
            desc = request.POST.get('selling_category_description', '')
            measurement = request.POST.get('measurement')
            price = request.POST.get('price')
            stock = request.POST.get('stock') or 0
            purchase_price = request.POST.get('purchase_price') or 0
            if name and measurement and price:
                category = SellingCategory.objects.create(
                    tenant=request.tenant,
                    name=name,
                    description=desc
                )
                SellingPrice.objects.create(
                    tenant=request.tenant,
                    category=category,
                    measurement=measurement,
                    price=price,
                    stock=stock,
                    purchase_price=purchase_price
                )
                messages.success(request, f"Selling category '{name}' added with price.")
            else:
                messages.error(request, "All fields are required.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        # ----- Existing actions (edit/delete category, add/edit/delete price) -----
        elif action == 'edit_selling_category':
            cat_id = request.POST.get('selling_category_id')
            name = request.POST.get('selling_category_name')
            desc = request.POST.get('selling_category_description', '')
            if cat_id and name:
                category = get_object_or_404(SellingCategory, id=cat_id, tenant=request.tenant)
                category.name = name
                category.description = desc
                category.save()
                messages.success(request, f"Selling category '{name}' updated.")
            else:
                messages.error(request, "Invalid data.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        elif action == 'delete_selling_category':
            cat_id = request.POST.get('selling_category_id')
            if cat_id:
                category = get_object_or_404(SellingCategory, id=cat_id, tenant=request.tenant)
                category.delete()
                messages.success(request, "Selling category deleted.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        elif action == 'add_selling_price':
            cat_id = request.POST.get('selling_category_id')
            measurement = request.POST.get('measurement')
            price = request.POST.get('price')
            stock = request.POST.get('stock') or 0
            purchase_price = request.POST.get('purchase_price') or 0
            if cat_id and measurement and price:
                category = get_object_or_404(SellingCategory, id=cat_id, tenant=request.tenant)
                SellingPrice.objects.create(tenant=request.tenant, category=category, measurement=measurement, price=price, stock=stock, purchase_price=purchase_price)
                messages.success(request, f"Price added for {category.name} ({measurement})")
            else:
                messages.error(request, "All fields are required.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        elif action == 'edit_selling_price':
            price_id = request.POST.get('selling_price_id')
            measurement = request.POST.get('measurement')
            price = request.POST.get('price')
            stock = request.POST.get('stock')
            purchase_price = request.POST.get('purchase_price')
            if price_id and measurement and price:
                selling_price = get_object_or_404(SellingPrice, id=price_id, tenant=request.tenant)
                selling_price.measurement = measurement
                selling_price.price = price
                if stock is not None:
                    selling_price.stock = stock
                if purchase_price is not None:
                    selling_price.purchase_price = purchase_price
                selling_price.save()
                messages.success(request, "Price updated.")
            else:
                messages.error(request, "All fields are required.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        elif action == 'edit_selling_category_with_price':
            cat_id = request.POST.get('category_id')
            price_id = request.POST.get('price_id')
            name = request.POST.get('category_name')
            desc = request.POST.get('category_description', '')
            measurement = request.POST.get('measurement')
            price = request.POST.get('price')
            stock = request.POST.get('stock') or 0
            purchase_price = request.POST.get('purchase_price') or 0
            if cat_id and name and measurement and price:
                category = get_object_or_404(SellingCategory, id=cat_id, tenant=request.tenant)
                category.name = name
                category.description = desc
                category.save()
                if price_id:
                    selling_price = get_object_or_404(SellingPrice, id=price_id, tenant=request.tenant, category=category)
                else:
                    selling_price = SellingPrice(tenant=request.tenant, category=category)
                selling_price.measurement = measurement
                selling_price.price = price
                selling_price.stock = stock
                selling_price.purchase_price = purchase_price
                selling_price.save()
                messages.success(request, f"Category '{name}' and price updated.")
            else:
                messages.error(request, "All fields are required.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)
        elif action == 'delete_selling_price':
            price_id = request.POST.get('selling_price_id')
            if price_id:
                selling_price = get_object_or_404(SellingPrice, id=price_id, tenant=request.tenant)
                selling_price.delete()
                messages.success(request, "Price deleted.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)


    template = 'mobile/settings.html' if request.mobile else 'desktop/settings.html'
    return render(request, template, {
        'categories': categories,
        'selling_categories': selling_categories,
    })

def search(request, **kwargs):
    tenant = request.tenant
    q = request.GET.get('q', '').strip()
    orders = []
    customers = []
    if q:
        orders = ChakkiOrder.objects.filter(
            Q(customer__name__icontains=q) |
            Q(customer__phone__icontains=q) |
            Q(id__icontains=q)
        ,
            tenant=request.tenant
        ).order_by('-created_at')
        customers = ChakkiCustomer.objects.filter(
            Q(name__icontains=q) |
            Q(phone__icontains=q)
        ,
            tenant=request.tenant
        )
    context = {
        'query': q,
        'orders': orders,
        'customers': customers,
        'tenant': tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/search.html' if request.mobile else 'desktop/search.html'
    return render(request, template, context)


@login_required
def get_transcript_modal(request, order_id, **kwargs):
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    context = {'order': order, 'tenant': request.tenant,
        "cancelled_count": cancelled_count,}
    return render(request, 'mobile/transcript_modal_content.html', context)


@login_required
def customer_list(request, **kwargs):
    tenant = request.tenant
    tab = request.GET.get('tab', 'regular')
    q = request.GET.get('q', '').strip()

    # Regular customers (is_regular=True)
    regular_customers = ChakkiCustomer.objects.filter(tenant=request.tenant, is_regular=True).order_by('name')
    if q:
        regular_customers = regular_customers.filter(
            Q(name__icontains=q) | Q(phone__icontains=q)
        )
    for customer in regular_customers:
        orders = ChakkiOrder.objects.filter(tenant=request.tenant, customer=customer)
        customer.total_pending = sum(o.remaining_amount for o in orders if o.status != 'completed')
        customer.total_orders = orders.count()

    # Walk-in customers with pending balance (is_regular=False and remaining_amount > 0)
    walk_customers = ChakkiCustomer.objects.filter(tenant=request.tenant, is_regular=False).order_by('name')
    if q:
        walk_customers = walk_customers.filter(
            Q(name__icontains=q) | Q(phone__icontains=q)
        )
    walk_customers_with_pending = []
    for customer in walk_customers:
        orders = ChakkiOrder.objects.filter(tenant=request.tenant, customer=customer)
        total_pending = sum(o.remaining_amount for o in orders if o.remaining_amount > 0)
        if total_pending > 0:
            customer.total_pending = total_pending
            customer.total_orders = orders.count()
            walk_customers_with_pending.append(customer)

    # Decide which list to display based on tab
    if tab == 'walk':
        customers = walk_customers_with_pending
    else:
        customers = regular_customers
        tab = 'regular'

    context = {
        'customers': customers,
        'tenant': tenant,
        'tab': tab,
        'regular_count': regular_customers.count(),
        'walk_count': len(walk_customers_with_pending),
        'search_q': q,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/customer_list.html' if request.mobile else 'desktop/customer_list.html'
    return render(request, template, context)

@login_required
def customer_profile(request, customer_id, **kwargs):
    customer = get_object_or_404(ChakkiCustomer, id=customer_id, tenant=request.tenant)
    orders = ChakkiOrder.objects.filter(tenant=request.tenant, customer=customer).exclude(status='cancelled').order_by('-created_at')
    total_pending = sum(o.remaining_amount for o in orders if o.status != 'completed')
    total_spent = sum(o.total_amount for o in orders if o.status == 'completed')
    context = {
        'customer': customer,
        'orders': orders,
        'total_pending': total_pending,
        'total_spent': total_spent,
        'total_orders': orders.count(),
        'tenant': request.tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/customer_profile.html' if request.mobile else 'desktop/customer_profile.html'
    return render(request, template, context)


@login_required

@login_required
def add_order(request, **kwargs):
    # We no longer need global setting for rates; use category rates.
    categories = ChakkiCategory.objects.filter(tenant=request.tenant)
    selling_categories = SellingCategory.objects.filter(tenant=request.tenant)
    tenant = request.tenant

    customer_id = request.GET.get('customer_id')
    walkin = request.GET.get('walkin') == '1'
    select = request.GET.get('select') == '1'

    if not customer_id and not walkin and not select:
        context = {'tenant': tenant,
        "cancelled_count": cancelled_count,}
        template = 'mobile/add_order_select.html' if request.mobile else 'desktop/add_order_select.html'
        return render(request, template, context)

    if select:
        q = request.GET.get('q', '').strip()
        customers = ChakkiCustomer.objects.filter(tenant=request.tenant, is_regular=True).order_by('name')
        if q:
            customers = customers.filter(Q(name__icontains=q) | Q(phone__icontains=q))
        for c in customers:
            orders = ChakkiOrder.objects.filter(tenant=request.tenant, customer=c)
            c.total_pending = sum(o.remaining_amount for o in orders if o.status != 'completed')
        context = {'customers': customers, 'tenant': tenant,
        "cancelled_count": cancelled_count,}
        template = 'mobile/add_order_customer_list.html' if request.mobile else 'desktop/add_order_customer_list.html'
        return render(request, template, context)

    customer = None
    if customer_id:
        customer = get_object_or_404(ChakkiCustomer, id=customer_id, tenant=request.tenant)
        orders = ChakkiOrder.objects.filter(tenant=request.tenant, customer=customer)
        customer.total_pending = sum(o.remaining_amount for o in orders if o.status != 'completed')

    if request.method == 'POST':
        payment_type = request.POST.get('payment_type', 'full')
        payment_amount = Decimal(request.POST.get('payment_amount', 0))

        if customer:
            cust = customer
        else:
            name = request.POST.get('name', '').strip()
            phone = request.POST.get('phone', '').strip()
            address = request.POST.get('address', '').strip()
            if not name:
                messages.error(request, "Name is required for walk-in customer.")
                return redirect('add_order', schema_name=tenant.schema_name)
            if payment_type == 'partial' and not phone:
                messages.error(request, "Phone is required for partial payment.")
                return redirect('add_order', schema_name=tenant.schema_name)
            if phone:
                existing = ChakkiCustomer.objects.filter(tenant=request.tenant, phone=phone).first()
                if existing:
                    if existing.is_regular:
                        messages.info(request, f"Phone number belongs to existing regular customer: {existing.name}.")
                        return redirect(f'/portal/{tenant.schema_name}/chakki/order/add/?customer_id={existing.id}')
                    else:
                        orders = ChakkiOrder.objects.filter(tenant=request.tenant, customer=existing)
                        has_pending = any(o.remaining_amount > 0 for o in orders)
                        if has_pending:
                            messages.info(request, f"Walk-in customer {existing.name} has pending balance. Please complete their orders first.")
                            return redirect(f'/portal/{tenant.schema_name}/chakki/order/add/?customer_id={existing.id}')
                        else:
                            customer = existing
                            messages.info(request, f"Reusing existing walk-in customer {existing.name} (no pending balance).")
            cust = ChakkiCustomer.objects.create(tenant=request.tenant,
                name=name,
                phone=phone,
                address=address
            )

        time_type = request.POST.get('time_type')
        time_value = int(request.POST.get('time_value', 0))
        ready_time = timezone.now()
        if time_type == 'minutes':
            ready_time += timezone.timedelta(minutes=time_value)
        elif time_type == 'hours':
            ready_time += timezone.timedelta(hours=time_value)
        elif time_type == 'days':
            ready_time += timezone.timedelta(days=time_value)

        order = ChakkiOrder.objects.create(tenant=request.tenant,
            customer=cust,
            ready_time=ready_time,
            status='pending'
        )
        item_count = int(request.POST.get('item_count', 0))
        for i in range(1, item_count + 1):
            item_type = request.POST.get(f'item_type_{i}')
            if item_type == 'grinding':
                category_id = request.POST.get(f'category_{i}')
                kg = request.POST.get(f'total_kg_{i}')
                cleaning = request.POST.get(f'cleaning_{i}') == 'on'
                if category_id and kg:
                    kg = Decimal(kg)
                    item = ChakkiOrderItem.objects.create(tenant=request.tenant,
                        order=order,
                        category_id=category_id,
                        total_kg=kg,
                        is_cleaning_done=cleaning
                    )
                    item.save()
            elif item_type == 'selling':
                selling_price_id = request.POST.get(f'selling_price_{i}')
                qty = request.POST.get(f'quantity_{i}')
                if selling_price_id and qty:
                    qty = Decimal(qty)
                    selling_price = get_object_or_404(SellingPrice, id=selling_price_id, tenant=request.tenant)
                    item = SellingOrderItem.objects.create(tenant=request.tenant,
                        order=order,
                        selling_price=selling_price,
                        quantity=qty
                    )
                    item.save()
        
        # Validate stock for selling items
        for i in range(1, item_count + 1):
            if request.POST.get(f'item_type_{i}') == 'selling':
                selling_price_id = request.POST.get(f'selling_price_{i}')
                qty = Decimal(request.POST.get(f'quantity_{i}'))
                if selling_price_id and qty:
                    selling_price = get_object_or_404(SellingPrice, id=selling_price_id, tenant=request.tenant)
                    if qty > selling_price.stock:
                        messages.error(request, f"Insufficient stock for {selling_price.category.name}. Available: {selling_price.stock}")
                        return redirect('add_order', schema_name=tenant.schema_name)

        order.save()  # triggers total recalculation

        # Decrement stock for selling items
        for i in range(1, item_count + 1):
            if request.POST.get(f'item_type_{i}') == 'selling':
                selling_price_id = request.POST.get(f'selling_price_{i}')
                qty = Decimal(request.POST.get(f'quantity_{i}'))
                if selling_price_id and qty:
                    selling_price = get_object_or_404(SellingPrice, id=selling_price_id, tenant=request.tenant)
                    selling_price.stock -= qty
                    selling_price.save()


        if payment_type == 'full':
            order.amount_paid = order.total_amount
        else:
            order.amount_paid = min(payment_amount, order.total_amount)
        order.save()
        messages.success(request, f"Order #{order.id} created! Ready at {ready_time.strftime('%I:%M %p')}")

        if not customer:
            return redirect('order_confirmation', schema_name=tenant.schema_name, order_id=order.id)
        else:
            return redirect('portal_dashboard', schema_name=tenant.schema_name)

    context = {
        'categories': categories,
        'selling_categories': selling_categories,
        'customer': customer,
        'walkin': walkin,
        'tenant': tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/add_order_form.html' if request.mobile else 'desktop/add_order_form.html'
    return render(request, template, context)

def order_confirmation(request, order_id, **kwargs):
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    context = {
        'order': order,
        'can_add_to_regulars': True,
        'tenant': request.tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/order_confirmation.html' if request.mobile else 'mobile/order_confirmation.html'
    return render(request, template, context)


@login_required
def add_customer_from_order(request, order_id, **kwargs):
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        phone = request.POST.get('phone', '').strip()
        address = request.POST.get('address', '').strip()
        if name and phone:
            existing = ChakkiCustomer.objects.filter(tenant=request.tenant, phone=phone).first()
            if existing:
                # If the existing customer is the same as the order's customer, just set is_regular=True
                if existing == order.customer:
                    existing.is_regular = True
                    existing.name = name
                    existing.address = address
                    existing.save()
                    messages.success(request, f"Customer {existing.name} added to regulars.")
                    return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=existing.id)
                else:
                    # Different customer with same phone: link order to existing and delete old if empty
                    old_customer = order.customer
                    order.customer = existing
                    order.save()
                    if old_customer != existing and old_customer.chakkiorder_set.count() == 0:
                        old_customer.delete()
                    messages.success(request, f"Order linked to existing customer {existing.name}.")
                    return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=existing.id)
            else:
                # New phone: update the order's customer to regular
                cust = order.customer
                cust.name = name
                cust.phone = phone
                cust.address = address
                cust.is_regular = True
                cust.save()
                messages.success(request, f"Customer {name} added to regulars.")
                return redirect('customer_profile', schema_name=request.tenant.schema_name, customer_id=cust.id)
        else:
            messages.error(request, "Name and Phone are required.")
    return redirect('order_confirmation', schema_name=request.tenant.schema_name, order_id=order_id)

@login_required
def complete_order_action(request, order_id, **kwargs):
    """Handle completion from pending list with confirmation and partial handling."""
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    if order.status == 'completed':
        messages.info(request, f"Order #{order.id} is already completed.")
        return redirect('chakki_home', schema_name=request.tenant.schema_name)

    # If fully paid, show confirmation page
    if order.remaining_amount == 0:
        if request.method == 'POST':
            order.status = 'completed'
            order.completed_at = timezone.now()
            order.save()
            messages.success(request, f"Order #{order.id} Completed!")
            return redirect('chakki_home', schema_name=request.tenant.schema_name)
        # GET: show confirmation template
        context = {'order': order, 'tenant': request.tenant, 'partial': False,
        "cancelled_count": cancelled_count,}
        template = 'mobile/order_complete_confirm.html' if request.mobile else 'desktop/order_complete_confirm.html'
        return render(request, template, context)

    # Partial payment: redirect to completion page with options
    return redirect('order_complete_partial', schema_name=request.tenant.schema_name, order_id=order.id)

@login_required
def order_complete_partial(request, order_id, **kwargs):
    """Page for partial paid orders to choose payment and complete."""
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    if order.status == 'completed':
        messages.info(request, "Order already completed.")
        return redirect('chakki_home', schema_name=request.tenant.schema_name)
    if order.remaining_amount == 0:
        return redirect('complete_order_action', schema_name=request.tenant.schema_name, order_id=order.id)

    if request.method == 'POST':
        payment_choice = request.POST.get('payment_choice')  # 'full' or 'partial'
        if payment_choice == 'full':
            # Pay full remaining
            order.amount_paid = order.total_amount
            order.status = 'completed'
            order.completed_at = timezone.now()
            order.save()
            messages.success(request, f"Order #{order.id} completed with full payment.")
            return redirect('chakki_home', schema_name=request.tenant.schema_name)

        elif payment_choice == 'partial':
            receive_amount = Decimal(request.POST.get('receive_amount', 0))
            if receive_amount > 0:
                new_paid = order.amount_paid + receive_amount
                if new_paid > order.total_amount:
                    new_paid = order.total_amount
                order.amount_paid = new_paid
                # Complete order regardless of full payment
                order.status = 'completed'
                order.completed_at = timezone.now()
                order.save()
                messages.success(request, f"Order #{order.id} completed. Received ₹{receive_amount:.2f}. Remaining balance: ₹{order.remaining_amount:.2f}")
                return redirect('chakki_home', schema_name=request.tenant.schema_name)
            else:
                messages.error(request, "Please enter a valid amount to receive.")
        else:
            messages.error(request, "Invalid payment choice.")

    context = {
        'order': order,
        'remaining': order.remaining_amount,
        'tenant': request.tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/order_complete_partial.html' if request.mobile else 'desktop/order_complete_partial.html'
    return render(request, template, context)

@login_required
def walk_profile(request, **kwargs):
    """List walk-in customers with any pending amount (unpaid balance)."""
    # Get all walk-in customers (is_regular=False) who have orders with remaining_amount > 0
    customers = ChakkiCustomer.objects.filter(tenant=request.tenant, is_regular=False)
    pending_customers = []
    for c in customers:
        orders = ChakkiOrder.objects.filter(tenant=request.tenant, customer=c)
        total_pending = sum(o.remaining_amount for o in orders if o.remaining_amount > 0)
        if total_pending > 0:
            c.total_pending = total_pending
            pending_customers.append(c)
    context = {
        'customers': pending_customers,
        'tenant': request.tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/walk_profile.html' if request.mobile else 'desktop/walk_profile.html'
    return render(request, template, context)

@login_required
def convert_walk_to_regular(request, customer_id, **kwargs):
    """Convert a walk-in customer to regular."""
    customer = get_object_or_404(ChakkiCustomer, id=customer_id, tenant=request.tenant)
    customer.is_regular = True
    customer.save()
    messages.success(request, f"Customer {customer.name} is now a regular customer.")
    return redirect('walk_profile', schema_name=request.tenant.schema_name)



@login_required
def create_customer(request, **kwargs):
    """Create a new regular customer."""
    tenant = request.tenant
    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        phone = request.POST.get('phone', '').strip()
        address = request.POST.get('address', '').strip()
        if not name or not phone:
            messages.error(request, "Name and Phone are required.")
            return redirect('create_customer', schema_name=tenant.schema_name)
        # Check if phone already exists
        existing = ChakkiCustomer.objects.filter(tenant=tenant, phone=phone).first()
        if existing:
            messages.info(request, f"Phone number already exists for customer {existing.name}. Please use a different phone or view their profile.")
            return redirect('create_customer', schema_name=tenant.schema_name)
        customer = ChakkiCustomer.objects.create(tenant=tenant, name=name, phone=phone, address=address, is_regular=True)
        messages.success(request, f"Customer {name} created successfully.")
        return redirect('customer_profile', schema_name=tenant.schema_name, customer_id=customer.id)
    context = {'tenant': tenant,
        "cancelled_count": cancelled_count,}
    template = 'mobile/create_customer.html' if request.mobile else 'desktop/create_customer.html'
    return render(request, template, context)


@login_required
def check_ready_orders(request, **kwargs):
    """Check for pending unpaid orders whose ready_time has passed, update them to 'ready',
       and return JSON with count and list of ready orders."""
    from django.utils import timezone
    from .models import ChakkiOrder

    tenant = request.tenant
    now = timezone.now()

    # Find pending unpaid orders that are past ready_time
    orders_to_update = ChakkiOrder.objects.filter(
        tenant=tenant,
        status='pending',
        amount_paid=0,
        ready_time__lte=now
    )
    updated_count = 0
    for order in orders_to_update:
        order.status = 'ready'
        order.save()
        updated_count += 1

    # Get all ready orders for display (latest first)
    ready_orders = ChakkiOrder.objects.filter(tenant=tenant, status='ready').order_by('-created_at')[:10]
    ready_list = [{'id': o.id, 'customer_name': o.customer.name} for o in ready_orders]

    return JsonResponse({
        'count': ready_orders.count(),
        'orders': ready_list,
        'updated': updated_count
    })


@login_required
def selling_prices_api(request, **kwargs):
    category_id = request.GET.get('category')
    if category_id:
        prices = SellingPrice.objects.filter(category_id=category_id, tenant=request.tenant, stock__gt=0)
        data = [{'id': p.id, 'measurement': p.get_measurement_display(), 'price': float(p.price), 'stock': float(p.stock)} for p in prices]
        return JsonResponse(data, safe=False)
    return JsonResponse([], safe=False)

# ---------- Category Detail Analytics ----------
@login_required
def grinding_category_detail(request, category_id, **kwargs):
    """Detailed analytics for a grinding category."""
    from django.db.models import Sum, Count, Q
    from decimal import Decimal

    category = get_object_or_404(ChakkiCategory, id=category_id, tenant=request.tenant)
    items = ChakkiOrderItem.objects.filter(category=category, tenant=request.tenant)
    orders = ChakkiOrder.objects.filter(items__in=items, tenant=request.tenant).distinct()

    total_orders = orders.count()
    total_kg = items.aggregate(Sum('total_kg'))['total_kg__sum'] or Decimal('0.00')
    total_revenue = items.aggregate(Sum('item_total'))['item_total__sum'] or Decimal('0.00')

    # Build order data with item totals
    order_data = []
    for order in orders.order_by('-created_at'):
        order_items = items.filter(order=order)
        order_total = order_items.aggregate(Sum('item_total'))['item_total__sum'] or Decimal('0.00')
        order_data.append({
            'order': order,
            'total': order_total,
            'items': order_items,
        })

    context = {
        'category': category,
        'total_orders': total_orders,
        'total_kg': total_kg,
        'total_revenue': total_revenue,
        'order_data': order_data,
        'type': 'grinding',
        'tenant': request.tenant,,
        "cancelled_count": cancelled_count,}
    template = 'mobile/category_detail.html' if request.mobile else 'desktop/category_detail.html'
    return render(request, template, context)


@login_required
def selling_category_detail(request, category_id, **kwargs):
    """Detailed analytics for a selling category."""
    from django.db.models import Sum, Count, Q
    from decimal import Decimal

    category = get_object_or_404(SellingCategory, id=category_id, tenant=request.tenant)
    items = SellingOrderItem.objects.filter(selling_price__category=category, tenant=request.tenant)
    orders = ChakkiOrder.objects.filter(selling_items__in=items, tenant=request.tenant).distinct()

    total_orders = orders.count()
    total_qty = items.aggregate(Sum('quantity'))['quantity__sum'] or Decimal('0.00')
    total_revenue = items.aggregate(Sum('total'))['total__sum'] or Decimal('0.00')
    total_cost = Decimal('0.00')
    total_profit = Decimal('0.00')

    order_data = []
    for order in orders.order_by('-created_at'):
        order_items = items.filter(order=order)
        order_total = order_items.aggregate(Sum('total'))['total__sum'] or Decimal('0.00')
        order_cost = Decimal('0.00')
        for item in order_items:
            cost = item.quantity * item.selling_price.purchase_price
            order_cost += cost
        order_profit = order_total - order_cost
        total_cost += order_cost
        total_profit += order_profit
        order_data.append({
            'order': order,
            'total': order_total,
            'cost': order_cost,
            'profit': order_profit,
            'items': order_items,
        })

    context = {
        'category': category,
        'total_orders': total_orders,
        'total_qty': total_qty,
        'total_revenue': total_revenue,
        'total_cost': total_cost,
        'total_profit': total_profit,
        'order_data': order_data,
        'type': 'selling',
        'tenant': request.tenant,
        "prices": category.prices.all(),,
        "cancelled_count": cancelled_count,}
    template = 'mobile/category_detail.html' if request.mobile else 'desktop/category_detail.html'
    return render(request, template, context)


@login_required
def cancel_order(request, order_id, **kwargs):
    from django.utils import timezone
    from datetime import timedelta
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)
    if order.status == 'completed':
        messages.error(request, "Completed orders cannot be cancelled.")
        return redirect('order_detail', schema_name=request.tenant.schema_name, order_id=order.id)
    if order.status == 'cancelled':
        messages.info(request, "Order already cancelled.")
        return redirect('order_detail', schema_name=request.tenant.schema_name, order_id=order.id)
    now = timezone.now()
    if now - order.created_at > timedelta(minutes=30):
        messages.error(request, "Order can only be cancelled within 30 minutes of creation.")
        return redirect('order_detail', schema_name=request.tenant.schema_name, order_id=order.id)
    order.status = 'cancelled'
    order.save()
    # Restore stock for selling items
    for item in order.selling_items.all():
        sp = item.selling_price
        sp.stock += item.quantity
        sp.save()
    messages.success(request, f"Order #{order.id} cancelled successfully.")
    return redirect('chakki_home', schema_name=request.tenant.schema_name)
