
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from .models import Expense

@login_required
def expense_list(request, **kwargs):
    expenses = Expense.objects.all().order_by('-date')
    total_given = sum(e.amount for e in expenses if e.is_credit and not e.is_repaid)
    total_taken = sum(e.amount for e in expenses if e.category == 'taken_loan' and not e.is_repaid)
    template = 'mobile/expenses.html' if request.mobile else 'desktop/expenses.html'
    return render(request, template, {
        'expenses': expenses,
        'total_given': total_given,
        'total_taken': total_taken,
    })

@login_required
def add_expense(request, **kwargs):
    if request.method == 'POST':
        Expense.objects.create(
            title=request.POST.get('title'),
            amount=request.POST.get('amount'),
            category=request.POST.get('category'),
            description=request.POST.get('description', ''),
            is_credit=request.POST.get('is_credit') == 'on',
            person_name=request.POST.get('person_name', ''),
            due_date=request.POST.get('due_date') or None,
        )
        messages.success(request, "Expense added!")
        return redirect('expense_list', schema_name=request.tenant.schema_name)
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
    return redirect('expense_list', schema_name=request.tenant.schema_name)
