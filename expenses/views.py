from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from .models import Expense

@login_required
def expense_list(request):
    expenses = Expense.objects.all().order_by('-date')
    total_given = sum(e.amount for e in expenses if e.is_credit)
    total_taken = sum(e.amount for e in expenses if e.category == 'taken_loan')
    template = 'mobile/expenses.html' if request.mobile else 'desktop/expenses.html'
    return render(request, template, {
        'expenses': expenses,
        'total_given': total_given,
        'total_taken': total_taken,
    })

@login_required
def add_expense(request):
    if request.method == 'POST':
        Expense.objects.create(
            title=request.POST.get('title'),
            amount=request.POST.get('amount'),
            category=request.POST.get('category'),
            description=request.POST.get('description', ''),
            is_credit=request.POST.get('is_credit') == 'on',
            person_name=request.POST.get('person_name', ''),
        )
        messages.success(request, "Expense added!")
        return redirect('expense_list')
    template = 'mobile/add_expense.html' if request.mobile else 'desktop/add_expense.html'
    return render(request, template)
