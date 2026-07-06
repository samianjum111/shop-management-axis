from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from django.db.models import Q, Sum
from django.http import JsonResponse
from .models import Expense, Reminder, Worker, WorkerCategory
import json

@login_required
def expense_dashboard(request, **kwargs):
    """Expense dashboard with cards and summary."""
    expenses = Expense.objects.all().order_by('-date')
    total_expenses = sum(e.amount for e in expenses)
    total_given = sum(e.amount for e in expenses if e.is_credit and not e.is_repaid)
    total_taken = sum(e.amount for e in expenses if e.category == 'taken_loan' and not e.is_repaid)
    net_balance = total_given - total_taken

    daily_expenses = expenses.filter(category__in=['general','food','medicine','utility','other']).count()
    loans_given = expenses.filter(category='given_loan').count()
    loans_taken = expenses.filter(category='taken_loan').count()
    reminders = Reminder.objects.filter(is_completed=False).count()
    workers = Worker.objects.filter(is_active=True).count()

    context = {
        'total_expenses': total_expenses,
        'total_given': total_given,
        'total_taken': total_taken,
        'net_balance': net_balance,
        'daily_expenses_count': daily_expenses,
        'loans_given_count': loans_given,
        'loans_taken_count': loans_taken,
        'reminders_count': reminders,
        'workers_count': workers,
        'tenant': request.tenant,
    }
    template = 'mobile/expenses.html' if request.mobile else 'desktop/expenses.html'
    return render(request, template, context)

@login_required
def daily_expense_list(request, **kwargs):
    """Enhanced daily expenses page with analytics, search, filters, and pagination."""
    from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger

    expenses = Expense.objects.filter(
        category__in=['general','food','medicine','utility','other']
    ).order_by('-expense_date')

    # Search
    search_q = request.GET.get('q', '').strip()
    if search_q:
        expenses = expenses.filter(
            Q(title__icontains=search_q) |
            Q(description__icontains=search_q) |
            Q(notes__icontains=search_q)
        )

    # Date range filter
    start_date = request.GET.get('start_date')
    end_date = request.GET.get('end_date')
    if start_date:
        expenses = expenses.filter(expense_date__gte=start_date)
    if end_date:
        expenses = expenses.filter(expense_date__lte=end_date)

    # Analytics (based on filtered queryset)
    today = timezone.now().date()
    today_total = expenses.filter(expense_date=today).aggregate(Sum('amount'))['amount__sum'] or 0
    week_start = today - timezone.timedelta(days=today.weekday())
    week_total = expenses.filter(expense_date__gte=week_start).aggregate(Sum('amount'))['amount__sum'] or 0
    month_start = today.replace(day=1)
    month_total = expenses.filter(expense_date__gte=month_start).aggregate(Sum('amount'))['amount__sum'] or 0
    overall_total = expenses.aggregate(Sum('amount'))['amount__sum'] or 0
    count = expenses.count()

    # Pagination (15 per page)
    paginator = Paginator(expenses, 15)
    page = request.GET.get('page')
    try:
        page_obj = paginator.page(page)
    except PageNotAnInteger:
        page_obj = paginator.page(1)
    except EmptyPage:
        page_obj = paginator.page(paginator.num_pages)

    context = {
        'page_obj': page_obj,
        'search_q': search_q,
        'start_date': start_date,
        'end_date': end_date,
        'today_total': today_total,
        'week_total': week_total,
        'month_total': month_total,
        'overall_total': overall_total,
        'count': count,
        'tenant': request.tenant,
    }
    template = 'mobile/daily_expenses.html' if request.mobile else 'desktop/daily_expenses.html'
    return render(request, template, context)

@login_required
def daily_expense_detail(request, expense_id, **kwargs):
    """Return expense data as JSON for modal."""
    expense = get_object_or_404(Expense, id=expense_id)
    data = {
        'id': expense.id,
        'title': expense.title,
        'description': expense.description,
        'amount': str(expense.amount),
        'expense_date': expense.expense_date.strftime('%Y-%m-%d'),
        'notes': expense.notes,
    }
    return JsonResponse(data)

@login_required
def daily_expense_add(request, **kwargs):
    """Create a new daily expense via AJAX."""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            expense = Expense.objects.create(
                title=data.get('title'),
                description=data.get('description', ''),
                amount=data.get('amount'),
                expense_date=data.get('expense_date'),
                notes=data.get('notes', ''),
                category='general',   # default category for daily expenses
            )
            return JsonResponse({'success': True, 'id': expense.id})
        except Exception as e:
            return JsonResponse({'success': False, 'error': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

@login_required
def daily_expense_edit(request, expense_id, **kwargs):
    """Update an existing daily expense via AJAX."""
    if request.method == 'POST':
        expense = get_object_or_404(Expense, id=expense_id)
        try:
            data = json.loads(request.body)
            expense.title = data.get('title', expense.title)
            expense.description = data.get('description', expense.description)
            expense.amount = data.get('amount', expense.amount)
            expense.expense_date = data.get('expense_date', expense.expense_date)
            expense.notes = data.get('notes', expense.notes)
            expense.save()
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'error': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

# ---- The following views are unchanged ----
@login_required
def loan_list(request, loan_type, **kwargs):
    if loan_type == 'given':
        expenses = Expense.objects.filter(category='given_loan').order_by('-date')
        title = 'Loans Given'
    else:
        expenses = Expense.objects.filter(category='taken_loan').order_by('-date')
        title = 'Loans Taken'
    context = {'expenses': expenses, 'title': title, 'loan_type': loan_type, 'tenant': request.tenant}
    template = 'mobile/expense_list.html' if request.mobile else 'desktop/expense_list.html'
    return render(request, template, context)

@login_required
def reminder_list(request, **kwargs):
    reminders = Reminder.objects.all().order_by('remind_date')
    context = {'reminders': reminders, 'tenant': request.tenant}
    template = 'mobile/reminder_list.html' if request.mobile else 'desktop/reminder_list.html'
    return render(request, template, context)

@login_required
def add_reminder(request, **kwargs):
    if request.method == 'POST':
        title = request.POST.get('title')
        notes = request.POST.get('notes', '')
        remind_date = request.POST.get('remind_date')
        if title and remind_date:
            Reminder.objects.create(
                title=title,
                notes=notes,
                remind_date=remind_date,
            )
            messages.success(request, "Reminder added!")
            return redirect('reminder_list', schema_name=request.tenant.schema_name)
    template = 'mobile/add_reminder.html' if request.mobile else 'desktop/add_reminder.html'
    return render(request, template)

@login_required
def complete_reminder(request, reminder_id, **kwargs):
    reminder = get_object_or_404(Reminder, id=reminder_id)
    reminder.is_completed = True
    reminder.save()
    messages.success(request, "Reminder marked as done.")
    return redirect('reminder_list', schema_name=request.tenant.schema_name)

@login_required
def worker_list(request, **kwargs):
    workers = Worker.objects.all().order_by('-created_at')
    categories = WorkerCategory.objects.all()
    context = {'workers': workers, 'categories': categories, 'tenant': request.tenant}
    template = 'mobile/worker_list.html' if request.mobile else 'desktop/worker_list.html'
    return render(request, template, context)

@login_required
def add_worker(request, **kwargs):
    categories = WorkerCategory.objects.all()
    if request.method == 'POST':
        name = request.POST.get('name')
        if not name:
            messages.error(request, "Name is required.")
            return redirect('add_worker', schema_name=request.tenant.schema_name)
        Worker.objects.create(
            name=name,
            father_name=request.POST.get('father_name', ''),
            cnic=request.POST.get('cnic', ''),
            phone=request.POST.get('phone', ''),
            address=request.POST.get('address', ''),
            joining_date=request.POST.get('joining_date'),
            resignation_date=request.POST.get('resignation_date') or None,
            status=request.POST.get('status', 'active'),
            salary_type=request.POST.get('salary_type', 'monthly'),
            salary_amount=request.POST.get('salary_amount', 0),
            category_id=request.POST.get('category') or None,
        )
        messages.success(request, f"Worker {name} added!")
        return redirect('worker_list', schema_name=request.tenant.schema_name)
    context = {'categories': categories, 'tenant': request.tenant}
    template = 'mobile/add_worker.html' if request.mobile else 'desktop/add_worker.html'
    return render(request, template)

@login_required
def add_worker_category(request, **kwargs):
    if request.method == 'POST':
        name = request.POST.get('name')
        if name:
            WorkerCategory.objects.create(name=name, description=request.POST.get('description', ''))
            messages.success(request, f"Category '{name}' added.")
        else:
            messages.error(request, "Category name required.")
        return redirect('worker_list', schema_name=request.tenant.schema_name)
    template = 'mobile/add_worker_category.html' if request.mobile else 'desktop/add_worker_category.html'
    return render(request, template)

@login_required
def edit_worker(request, worker_id, **kwargs):
    worker = get_object_or_404(Worker, id=worker_id)
    categories = WorkerCategory.objects.all()
    if request.method == 'POST':
        worker.name = request.POST.get('name', worker.name)
        worker.father_name = request.POST.get('father_name', worker.father_name)
        worker.cnic = request.POST.get('cnic', worker.cnic)
        worker.phone = request.POST.get('phone', worker.phone)
        worker.address = request.POST.get('address', worker.address)
        worker.joining_date = request.POST.get('joining_date', worker.joining_date)
        worker.resignation_date = request.POST.get('resignation_date') or None
        worker.status = request.POST.get('status', worker.status)
        worker.salary_type = request.POST.get('salary_type', worker.salary_type)
        worker.salary_amount = request.POST.get('salary_amount', worker.salary_amount)
        worker.category_id = request.POST.get('category') or None
        worker.save()
        messages.success(request, "Worker updated!")
        return redirect('worker_list', schema_name=request.tenant.schema_name)
    context = {'worker': worker, 'categories': categories, 'tenant': request.tenant}
    template = 'mobile/edit_worker.html' if request.mobile else 'desktop/edit_worker.html'
    return render(request, template)

@login_required
def add_expense(request, **kwargs):
    if request.method == 'POST':
        expense = Expense(
            title=request.POST.get('title'),
            amount=request.POST.get('amount'),
            category=request.POST.get('category'),
            description=request.POST.get('description', ''),
            is_credit=request.POST.get('is_credit') == 'on',
            person_name=request.POST.get('person_name', ''),
            due_date=request.POST.get('due_date') or None,
            phone=request.POST.get('phone', ''),
            address=request.POST.get('address', ''),
            notes=request.POST.get('notes', ''),
            reason=request.POST.get('reason', ''),
        )
        expense.save()
        messages.success(request, "Expense added!")
        return redirect('expense_dashboard', schema_name=request.tenant.schema_name)
    template = 'mobile/add_expense.html' if request.mobile else 'desktop/add_expense.html'
    return render(request, template)

@login_required
def repay_loan(request, expense_id, **kwargs):
    expense = get_object_or_404(Expense, id=expense_id)
    if expense.is_credit or expense.category == 'taken_loan':
        expense.is_repaid = True
        expense.save()
        messages.success(request, f"Loan {expense.title} marked as repaid.")
    else:
        messages.error(request, "This is not a loan entry.")
    return redirect('expense_dashboard', schema_name=request.tenant.schema_name)
