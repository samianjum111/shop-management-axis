#!/usr/bin/env python3
"""
Single patcher for order completion logic.
Run: python3 patcher.py
"""

import os
import re

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def patch_views():
    path = 'chakki/views.py'
    content = read_file(path)

    # 1. Replace complete_order_action with unified version
    new_complete_action = '''
@login_required
def complete_order_action(request, order_id, **kwargs):
    """Unified completion: handles full and partial payments on one page."""
    order = get_object_or_404(ChakkiOrder, id=order_id, tenant=request.tenant)

    if order.status == 'completed':
        messages.info(request, f"Order #{order.id} is already completed.")
        return redirect('chakki_home', schema_name=request.tenant.schema_name)

    if request.method == 'POST':
        payment_choice = request.POST.get('payment_choice')
        if payment_choice == 'full':
            # Pay remaining in full
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
                order.status = 'completed'
                order.completed_at = timezone.now()
                order.save()
                messages.success(request,
                    f"Order #{order.id} completed. Received ₹{receive_amount:.2f}. "
                    f"Remaining balance: ₹{order.remaining_amount:.2f}")
                return redirect('chakki_home', schema_name=request.tenant.schema_name)
            else:
                messages.error(request, "Please enter a valid amount to receive.")
        else:
            messages.error(request, "Invalid payment choice.")
        # If error, re‑render the page with messages

    # GET or after POST error: show the confirmation page with payment options if partial
    context = {
        'order': order,
        'tenant': request.tenant,
        'partial': order.remaining_amount > 0,   # flag for template
        'remaining': order.remaining_amount,
    }
    template = 'mobile/order_complete_confirm.html' if request.mobile else 'desktop/order_complete_confirm.html'
    return render(request, template, context)
'''
    # Find the old complete_order_action function and replace it
    pattern = r'@login_required\s+def complete_order_action\(request, order_id, \*\*kwargs\):.*?(?=\n@login_required|\Z)'
    # We'll use a more robust approach: locate the function by its signature and replace until next function.
    # Since the file content is large, we'll do a simple replace by finding the exact existing function block.
    # But we can also use a marker approach: we'll replace the whole function with our new one.
    # We'll locate the start of the function and then find the end (next def or end of file).
    start_marker = '@login_required\ndef complete_order_action'
    end_marker = '\n@login_required'  # next decorator
    # We'll use re.DOTALL to match across lines.
    # We need to capture the entire function including its body.
    # Simpler: we can replace the content between the start and the next function.
    # But there might be multiple @login_required. We'll match the exact function.

    # Let's build a regex to find the function from its signature to the next function definition (ignoring comments).
    # We'll use a more manual approach: find the line with "def complete_order_action", then find the next line that starts with "def " at the same indentation level (0) or next @login_required.
    # We'll use a simple search and replace using a known pattern from the current code.

    # The current function as provided in the dump. We'll locate it and replace.
    # We'll use the exact existing code to replace.
    old_func = '''@login_required
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
        context = {'order': order, 'tenant': request.tenant, 'partial': False}
        template = 'mobile/order_complete_confirm.html' if request.mobile else 'desktop/order_complete_confirm.html'
        return render(request, template, context)

    # Partial payment: redirect to completion page with options
    return redirect('order_complete_partial', schema_name=request.tenant.schema_name, order_id=order.id)'''

    # Replace with new function
    if old_func in content:
        content = content.replace(old_func, new_complete_action.strip())
    else:
        print("Warning: Could not find old complete_order_action function. Skipping.")

    # 2. Modify order_complete_partial to redirect to complete_action
    # We'll replace its body with a redirect.
    old_partial = '''@login_required
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
        'tenant': request.tenant,
    }
    template = 'mobile/order_complete_partial.html' if request.mobile else 'desktop/order_complete_partial.html'
    return render(request, template, context)'''

    new_partial = '''@login_required
def order_complete_partial(request, order_id, **kwargs):
    """Redirect to the unified complete_action."""
    return redirect('complete_order_action', schema_name=request.tenant.schema_name, order_id=order_id)'''

    if old_partial in content:
        content = content.replace(old_partial, new_partial.strip())
    else:
        print("Warning: Could not find old order_complete_partial function. Skipping.")

    write_file(path, content)
    print("✅ Updated chakki/views.py")

def patch_templates():
    # 1. Desktop order_complete_confirm.html
    path = 'templates/desktop/order_complete_confirm.html'
    content = read_file(path)
    # We need to modify to show payment options if partial flag is True.
    # The current template has a form with choice buttons? Let's replace the entire form section.
    # We'll keep the order summary and add conditional payment options.
    # We'll replace the whole content with a new version that includes conditional logic.
    new_desktop_confirm = '''{% extends "desktop/base.html" %}
{% load static %}
{% block title %}Complete Order #{{ order.id }} | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
  /* ===== Premium Order Completion ===== */
  .confirm-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 70vh;
    padding: 1.5rem;
  }
  .confirm-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 28px;
    padding: 2.5rem 2rem;
    max-width: 680px;
    width: 100%;
    box-shadow: 0 12px 40px rgba(0,0,0,0.05);
    transition: box-shadow 0.35s ease;
  }
  .confirm-card:hover {
    box-shadow: 0 20px 60px rgba(0,0,0,0.08);
  }

  .confirm-icon {
    font-size: 3rem;
    color: var(--accent);
    background: rgba(245, 158, 11, 0.08);
    width: 72px;
    height: 72px;
    line-height: 72px;
    border-radius: 50%;
    margin: 0 auto 1rem;
    display: inline-block;
    text-align: center;
  }
  .confirm-card h4 {
    font-size: 1.6rem;
    font-weight: 700;
    color: var(--text);
    margin-bottom: 0.2rem;
    letter-spacing: -0.02em;
    text-align: center;
  }
  .confirm-card .order-meta {
    text-align: center;
    font-size: 0.95rem;
    color: var(--text-secondary);
    margin-bottom: 1.2rem;
  }
  .confirm-card .order-meta .order-id {
    font-weight: 600;
    color: var(--accent);
  }
  .confirm-card .order-meta .customer {
    font-weight: 500;
  }

  .section-title {
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin: 1.5rem 0 0.5rem;
    border-bottom: 1px solid var(--border);
    padding-bottom: 0.3rem;
  }

  .items-table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0 4px;
    font-size: 0.9rem;
    margin-bottom: 1rem;
  }
  .items-table thead th {
    background: var(--surface-alt);
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 0.5rem 0.8rem;
    border: none;
    text-align: left;
  }
  .items-table thead th:last-child { text-align: right; }
  .items-table tbody td {
    padding: 0.4rem 0.8rem;
    border-bottom: 1px solid var(--border);
    color: var(--text);
  }
  .items-table tbody tr:last-child td { border-bottom: none; }
  .items-table tbody tr:hover td { background: var(--bg); }
  .items-table .amount { text-align: right; font-weight: 500; }
  .items-table .total-row td {
    font-weight: 700;
    border-top: 2px solid var(--text);
    padding-top: 0.6rem;
  }
  .items-table .total-row .amount {
    color: var(--accent);
    font-size: 1.1rem;
  }
  .items-table .highlight { background: var(--surface-alt); }

  .balance-summary {
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    background: var(--surface-alt);
    border-radius: 16px;
    padding: 0.8rem 1.2rem;
    margin: 1.2rem 0 1.8rem;
    gap: 0.5rem;
  }
  .balance-summary .item {
    text-align: center;
  }
  .balance-summary .item .label {
    font-size: 0.7rem;
    text-transform: uppercase;
    color: var(--muted);
    font-weight: 600;
    letter-spacing: 0.04em;
  }
  .balance-summary .item .value {
    font-size: 1.4rem;
    font-weight: 700;
    color: var(--text);
  }
  .balance-summary .item .value.remaining {
    color: var(--accent);
  }

  .choice-group {
    display: flex;
    gap: 1rem;
    justify-content: center;
    margin-bottom: 1.8rem;
    flex-wrap: wrap;
  }
  .choice-btn {
    background: var(--surface-alt);
    border: 2px solid var(--border);
    border-radius: 16px;
    padding: 0.8rem 1.2rem;
    cursor: pointer;
    transition: all 0.25s ease;
    flex: 1;
    min-width: 120px;
    text-align: center;
  }
  .choice-btn:hover {
    border-color: var(--accent);
    transform: translateY(-2px);
  }
  .choice-btn.active {
    border-color: var(--accent);
    background: rgba(245, 158, 11, 0.08);
  }
  .choice-btn .icon {
    font-size: 1.8rem;
    display: block;
    margin-bottom: 0.2rem;
    color: var(--text-secondary);
  }
  .choice-btn.active .icon {
    color: var(--accent);
  }
  .choice-btn .label {
    font-weight: 600;
    color: var(--text);
  }

  .partial-section {
    display: none;
    margin-top: 0.5rem;
    animation: fadeSlide 0.3s ease;
  }
  .partial-section.visible {
    display: block;
  }

  @keyframes fadeSlide {
    0% { opacity: 0; transform: translateY(-8px); }
    100% { opacity: 1; transform: translateY(0); }
  }

  .form-group {
    margin-bottom: 1.2rem;
    text-align: left;
  }
  .form-group label {
    display: block;
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--text-secondary);
    margin-bottom: 0.3rem;
  }
  .form-group .input-wrapper {
    position: relative;
  }
  .form-group .input-wrapper .currency {
    position: absolute;
    left: 14px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--muted);
    font-weight: 600;
    font-size: 1rem;
  }
  .form-group input {
    width: 100%;
    padding: 0.7rem 1rem 0.7rem 2.4rem;
    border: 1.5px solid var(--border);
    border-radius: 14px;
    background: var(--bg);
    color: var(--text);
    font-size: 1rem;
    transition: all 0.2s ease;
    outline: none;
  }
  .form-group input:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 4px rgba(245, 158, 11, 0.08);
  }
  .form-group .hint {
    display: block;
    margin-top: 0.3rem;
    font-size: 0.8rem;
    color: var(--text-secondary);
  }

  .actions {
    display: flex;
    flex-wrap: wrap;
    gap: 0.8rem;
    justify-content: center;
    margin-top: 1.8rem;
  }
  .btn-premium-primary {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: 40px;
    padding: 0.7rem 2.2rem;
    font-weight: 600;
    font-size: 1rem;
    transition: all 0.25s ease;
    box-shadow: 0 4px 14px rgba(245, 158, 11, 0.2);
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    text-decoration: none;
  }
  .btn-premium-primary:hover {
    background: var(--accent-hover);
    transform: translateY(-2px);
    box-shadow: 0 8px 28px rgba(245, 158, 11, 0.3);
    color: #fff;
  }

  .btn-premium-success {
    background: #28a745;
    color: #fff;
    border: none;
    border-radius: 40px;
    padding: 0.7rem 2.2rem;
    font-weight: 600;
    font-size: 1rem;
    transition: all 0.25s ease;
    box-shadow: 0 4px 14px rgba(40, 167, 69, 0.2);
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
  }
  .btn-premium-success:hover {
    background: #1e7e34;
    transform: translateY(-2px);
    box-shadow: 0 8px 28px rgba(40, 167, 69, 0.3);
    color: #fff;
  }

  .btn-premium-secondary {
    background: transparent;
    color: var(--text-secondary);
    border: 1.5px solid var(--border);
    border-radius: 40px;
    padding: 0.7rem 2rem;
    font-weight: 600;
    font-size: 1rem;
    transition: all 0.25s ease;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    text-decoration: none;
  }
  .btn-premium-secondary:hover {
    background: var(--surface-alt);
    border-color: var(--accent);
    color: var(--accent);
    transform: translateY(-2px);
    text-decoration: none;
  }

  @media (max-width: 600px) {
    .confirm-card { padding: 1.5rem; }
    .balance-summary { flex-direction: column; align-items: stretch; gap: 0.3rem; }
    .balance-summary .item { display: flex; justify-content: space-between; }
    .choice-group { flex-direction: column; }
    .choice-btn { min-width: auto; }
    .actions { flex-direction: column; }
    .actions .btn { width: 100%; justify-content: center; }
    .items-table { font-size: 0.8rem; }
  }
</style>
{% endblock %}

{% block content %}
<div class="confirm-wrapper">
  <div class="confirm-card">
    <!-- Icon -->
    <div class="confirm-icon">
      <i class="fas fa-hand-holding-usd"></i>
    </div>
    <h4>Complete Order</h4>
    <div class="order-meta">
      <span class="order-id">#{{ order.id }}</span>
      &middot;
      <span class="customer">{{ order.customer.name }}</span>
    </div>

    <!-- Order Items -->
    <div class="section-title">Grinding Items</div>
    <table class="items-table">
      <thead>
        <tr>
          <th>Category</th>
          <th>KG</th>
          <th>Cleaning</th>
          <th class="amount">Grinding</th>
          <th class="amount">Cleaning Charges</th>
          <th class="amount">Total</th>
        </tr>
      </thead>
      <tbody>
        {% for item in order.items.all %}
        <tr>
          <td>{{ item.category.name }}</td>
          <td>{{ item.total_kg }}</td>
          <td>{{ item.is_cleaning_done|yesno:"Yes,No" }}</td>
          <td class="amount">₹{{ item.grinding_charges|floatformat:2 }}</td>
          <td class="amount">₹{{ item.cleaning_charges|floatformat:2 }}</td>
          <td class="amount">₹{{ item.item_total|floatformat:2 }}</td>
        </tr>
        {% empty %}
        <tr><td colspan="6" style="text-align:center;color:var(--muted);">No grinding items</td></tr>
        {% endfor %}
        <tr class="total-row">
          <td colspan="5" style="text-align:right;">Grinding Total</td>
          <td class="amount">₹{{ order.total_amount|floatformat:2 }}</td>
        </tr>
      </tbody>
    </table>

    {% if order.selling_items.all %}
    <div class="section-title">Selling Items</div>
    <table class="items-table">
      <thead>
        <tr>
          <th>Item</th>
          <th>Measurement</th>
          <th>Quantity</th>
          <th class="amount">Price</th>
          <th class="amount">Total</th>
        </tr>
      </thead>
      <tbody>
        {% for item in order.selling_items.all %}
        <tr>
          <td>{{ item.selling_price.category.name }}</td>
          <td>{{ item.selling_price.get_measurement_display }}</td>
          <td>{{ item.quantity }}</td>
          <td class="amount">₹{{ item.selling_price.price|floatformat:2 }}</td>
          <td class="amount">₹{{ item.total|floatformat:2 }}</td>
        </tr>
        {% endfor %}
        <tr class="total-row">
          <td colspan="4" style="text-align:right;">Selling Total</td>
          <td class="amount">₹{{ order.selling_total|default:0|floatformat:2 }}</td>
        </tr>
      </tbody>
    </table>
    {% endif %}

    <!-- Balance Summary -->
    <div class="balance-summary">
      <div class="item">
        <div class="label">Grand Total</div>
        <div class="value">₹{{ order.total_amount|floatformat:2 }}</div>
      </div>
      <div class="item">
        <div class="label">Amount Paid</div>
        <div class="value">₹{{ order.amount_paid|floatformat:2 }}</div>
      </div>
      <div class="item">
        <div class="label">Remaining</div>
        <div class="value remaining">₹{{ remaining|floatformat:2 }}</div>
      </div>
    </div>

    <form method="post" id="paymentForm">
      {% csrf_token %}

      {% if partial %}
        <!-- If partially paid, show payment choice -->
        <div class="choice-group">
          <div class="choice-btn active" data-choice="full" onclick="selectChoice('full')">
            <span class="icon"><i class="fas fa-check-circle"></i></span>
            <span class="label">Full Payment</span>
          </div>
          <div class="choice-btn" data-choice="partial" onclick="selectChoice('partial')">
            <span class="icon"><i class="fas fa-pen"></i></span>
            <span class="label">Partial Payment</span>
          </div>
        </div>

        <!-- Partial section -->
        <div class="partial-section" id="partialSection">
          <div class="form-group">
            <label for="receive_amount">Enter amount to receive</label>
            <div class="input-wrapper">
              <span class="currency">₹</span>
              <input type="number" step="0.01" min="0.01" max="{{ remaining }}" name="receive_amount" id="receive_amount" class="form-control" placeholder="e.g. 250.00">
            </div>
            <span class="hint">Maximum: ₹{{ remaining|floatformat:2 }}</span>
          </div>
        </div>

        <!-- Actions for partial -->
        <div class="actions">
          <button type="submit" name="payment_choice" value="full" class="btn-premium-primary" id="fullBtn">
            <i class="fas fa-check-circle"></i> Complete Order
          </button>
          <button type="submit" name="payment_choice" value="partial" class="btn-premium-success" id="partialBtn" style="display:none;">
            <i class="fas fa-arrow-right"></i> Receive & Complete
          </button>
          <a href="{% url 'chakki_home' schema_name=tenant.schema_name %}" class="btn-premium-secondary">
            <i class="fas fa-times"></i> Cancel
          </a>
        </div>
      {% else %}
        <!-- Fully paid: only confirm -->
        <div class="actions">
          <button type="submit" name="payment_choice" value="full" class="btn-premium-primary">
            <i class="fas fa-check-circle"></i> Confirm Completion
          </button>
          <a href="{% url 'chakki_home' schema_name=tenant.schema_name %}" class="btn-premium-secondary">
            <i class="fas fa-times"></i> Cancel
          </a>
        </div>
      {% endif %}
    </form>
  </div>
</div>

<script>
  function selectChoice(choice) {
    const fullBtn = document.getElementById('fullBtn');
    const partialBtn = document.getElementById('partialBtn');
    const partialSection = document.getElementById('partialSection');
    const choiceBtns = document.querySelectorAll('.choice-btn');

    choiceBtns.forEach(btn => btn.classList.remove('active'));

    if (choice === 'full') {
      document.querySelector('.choice-btn[data-choice="full"]').classList.add('active');
      if (fullBtn) fullBtn.style.display = 'inline-flex';
      if (partialBtn) partialBtn.style.display = 'none';
      if (partialSection) partialSection.classList.remove('visible');
      document.getElementById('receive_amount').required = false;
    } else {
      document.querySelector('.choice-btn[data-choice="partial"]').classList.add('active');
      if (fullBtn) fullBtn.style.display = 'none';
      if (partialBtn) partialBtn.style.display = 'inline-flex';
      if (partialSection) partialSection.classList.add('visible');
      document.getElementById('receive_amount').required = true;
      const max = {{ remaining|floatformat:2 }};
      document.getElementById('receive_amount').max = max;
    }
  }

  document.addEventListener('DOMContentLoaded', function() {
    {% if partial %}
      selectChoice('full');
    {% endif %}
  });
</script>

{% endblock %}
'''
    write_file(path, new_desktop_confirm)
    print("✅ Updated templates/desktop/order_complete_confirm.html")

    # 2. Mobile order_complete_confirm.html
    path = 'templates/mobile/order_complete_confirm.html'
    content = read_file(path)
    new_mobile_confirm = '''{% extends "mobile/base.html" %}
{% block title %}Confirm Complete Order #{{ order.id }} | {{ tenant.name }}{% endblock %}
{% block extra_head %}
<style>
  .payment-option { cursor: pointer; padding: 0.8rem; border: 2px solid var(--border); border-radius: var(--radius); margin-bottom: 0.5rem; }
  .payment-option.selected { border-color: var(--accent); background: var(--accent-light); }
  .amount-row { display: flex; align-items: center; gap: 0.5rem; margin: 0.5rem 0; }
</style>
{% endblock %}
{% block body %}
<div class="card p-4">
  <h4>Complete Order #{{ order.id }}</h4>
  <p><strong>Customer:</strong> {{ order.customer.name }}</p>
  <div class="row">
    <div class="col-6"><strong>Total:</strong> ₹{{ order.total_amount|floatformat:2 }}</div>
    <div class="col-6"><strong>Paid:</strong> ₹{{ order.amount_paid|floatformat:2 }}</div>
    <div class="col-6"><strong>Remaining:</strong> ₹{{ remaining|floatformat:2 }}</div>
  </div>
  <hr>
  <form method="post" id="partialForm">
    {% csrf_token %}
    {% if partial %}
      <div class="payment-option" data-value="full" onclick="selectPayment('full')">
        <strong>Full Payment</strong>
        <p class="text-muted small">Pay the remaining ₹{{ remaining|floatformat:2 }} now.</p>
      </div>
      <div class="payment-option" data-value="partial" onclick="selectPayment('partial')">
        <strong>Partial Payment</strong>
        <p class="text-muted small">Receive a part of the remaining amount now.</p>
      </div>
      <input type="hidden" name="payment_choice" id="payment_choice" value="full">

      <div id="partial_amount_div" style="display:none; margin-top: 0.5rem;">
        <label>Amount Receiving (₹)</label>
        <div class="amount-row">
          <input type="number" name="receive_amount" id="receive_amount" step="0.01" class="form-control" value="{{ remaining }}">
          <span id="new_remaining_display" class="text-muted">Remaining: ₹0.00</span>
        </div>
      </div>

      <button type="submit" class="btn btn-primary-custom w-100 mt-3">Complete Order</button>
    {% else %}
      <p>This order is fully paid. Are you sure you want to mark it as <strong>Completed</strong>?</p>
      <button type="submit" name="payment_choice" value="full" class="btn btn-primary-custom w-100">Yes, I'm sure</button>
    {% endif %}
    <a href="{% url 'chakki_home' schema_name=tenant.schema_name %}" class="btn btn-secondary w-100 mt-2">Cancel</a>
  </form>
</div>

<script>
  function selectPayment(val) {
    document.querySelectorAll('.payment-option').forEach(el => el.classList.remove('selected'));
    document.querySelector(`.payment-option[data-value="${val}"]`).classList.add('selected');
    document.getElementById('payment_choice').value = val;
    const div = document.getElementById('partial_amount_div');
    if (val === 'partial') {
      div.style.display = 'block';
    } else {
      div.style.display = 'none';
    }
    updateRemaining();
  }

  function updateRemaining() {
    const rem = parseFloat("{{ remaining|escapejs }}");
    const receive = parseFloat(document.getElementById('receive_amount')?.value) || 0;
    const newRem = Math.max(0, rem - receive);
    const display = document.getElementById('new_remaining_display');
    if (display) display.textContent = 'Remaining: ₹' + newRem.toFixed(2);
  }
  document.getElementById('receive_amount')?.addEventListener('input', updateRemaining);
  {% if partial %}
    selectPayment('full');
  {% endif %}
</script>
{% endblock %}
'''
    write_file(path, new_mobile_confirm)
    print("✅ Updated templates/mobile/order_complete_confirm.html")

    # 3. Add "Collect Pending" button in desktop chakki.html
    path = 'templates/desktop/chakki.html'
    content = read_file(path)
    # We need to find the section where actions are defined.
    # Look for: <div class="actions"> and add a new button for completed partial orders.
    # We'll replace the existing action buttons block.
    # The current actions block:
    # <div class="actions">
    #   {% if order.status != 'completed' %}
    #     <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn btn-success btn-sm">✅ Complete</a>
    #   {% endif %}
    #   ...
    # </div>
    # We'll add a new condition before the "View" button.
    # We'll search for the pattern and replace.
    # Let's find the actions block.
    pattern = r'(<div class="actions">)(.*?)(</div>)'
    # We'll replace with a new block that includes the collect pending button.
    # We'll use a simpler approach: add the button after the Complete button.
    # We'll look for the "Complete" button and insert after it.
    complete_btn = '<a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn btn-success btn-sm">✅ Complete</a>'
    new_complete_btn = '''{% if order.status != 'completed' %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn btn-success btn-sm">✅ Complete</a>
      {% endif %}
      {% if order.status == 'completed' and order.payment_status == 'partial' %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn btn-warning btn-sm">💰 Collect Pending</a>
      {% endif %}'''
    # Replace the existing Complete button block with the new one.
    # But careful: the existing block may have the whole if.
    # We'll locate the line with "Complete" and replace the surrounding.
    # Simpler: we can replace the entire actions div.
    # Let's search for the actions div and replace with a new one that includes both.
    old_actions = '''<div class="actions">
    {% if order.status != 'completed' %}
      <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn btn-success btn-sm">✅ Complete</a>
    {% endif %}
    {% if order.can_cancel %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/cancel/{{ order.id }}/" class="btn btn-danger btn-sm" onclick="return confirm(\\'Cancel this order?\\')">Cancel</a>
    {% endif %}
    <button class="btn btn-outline-secondary btn-sm view-transcript" data-order-id="{{ order.id }}">📄 Transcript</button>
    <a href="/portal/{{ tenant.schema_name }}/chakki/order/{{ order.id }}/" class="btn btn-outline-primary btn-sm">View</a>
  </div>'''
    new_actions = '''<div class="actions">
    {% if order.status != 'completed' %}
      <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn btn-success btn-sm">✅ Complete</a>
    {% endif %}
    {% if order.status == 'completed' and order.payment_status == 'partial' %}
      <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn btn-warning btn-sm">💰 Collect Pending</a>
    {% endif %}
    {% if order.can_cancel %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/cancel/{{ order.id }}/" class="btn btn-danger btn-sm" onclick="return confirm(\\'Cancel this order?\\')">Cancel</a>
    {% endif %}
    <button class="btn btn-outline-secondary btn-sm view-transcript" data-order-id="{{ order.id }}">📄 Transcript</button>
    <a href="/portal/{{ tenant.schema_name }}/chakki/order/{{ order.id }}/" class="btn btn-outline-primary btn-sm">View</a>
  </div>'''
    if old_actions in content:
        content = content.replace(old_actions, new_actions)
        write_file(path, content)
        print("✅ Updated templates/desktop/chakki.html")
    else:
        print("⚠️ Could not find actions block in desktop/chakki.html. Skipping.")

    # 4. Mobile chakki.html
    path = 'templates/mobile/chakki.html'
    content = read_file(path)
    # Similar change: in the order card, there is a div with class "actions".
    old_mobile_actions = '''<div class="actions">
            {% if order.status != 'completed' %}
                <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn-action primary">✅ Complete</a>
            {% endif %}
            {% if order.can_cancel %}
            <a href="/portal/{{ tenant.schema_name }}/chakki/cancel/{{ order.id }}/" class="btn-action outline" onclick="return confirm(\\'Cancel this order?\\')">Cancel</a>
            {% endif %}
            <button class="btn-action secondary view-transcript" data-order-id="{{ order.id }}">📄 Transcript</button>
        </div>'''
    new_mobile_actions = '''<div class="actions">
            {% if order.status != 'completed' %}
                <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn-action primary">✅ Complete</a>
            {% endif %}
            {% if order.status == 'completed' and order.payment_status == 'partial' %}
                <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ order.id }}/" class="btn-action outline" style="background:#fef3e2;color:#d35400;">💰 Collect Pending</a>
            {% endif %}
            {% if order.can_cancel %}
            <a href="/portal/{{ tenant.schema_name }}/chakki/cancel/{{ order.id }}/" class="btn-action outline" onclick="return confirm(\\'Cancel this order?\\')">Cancel</a>
            {% endif %}
            <button class="btn-action secondary view-transcript" data-order-id="{{ order.id }}">📄 Transcript</button>
        </div>'''
    if old_mobile_actions in content:
        content = content.replace(old_mobile_actions, new_mobile_actions)
        write_file(path, content)
        print("✅ Updated templates/mobile/chakki.html")
    else:
        print("⚠️ Could not find actions block in mobile/chakki.html. Skipping.")

    # 5. Desktop order_list.html
    path = 'templates/desktop/order_list.html'
    content = read_file(path)
    # In the table, there is an action column.
    # We need to add a condition for completed partial orders to show "Collect Pending".
    # Look for: <td> and inside an if block.
    # We'll replace the existing action column content.
    old_action_cell = '''<td>
          {% if o.status != 'completed' %}
            <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ o.id }}/" class="btn-sm-premium btn-sm-primary">
              <i class="fas fa-check-circle"></i> Complete
            </a>
          {% else %}
            <a href="/portal/{{ tenant.schema_name }}/chakki/order/{{ o.id }}/" class="btn-sm-premium btn-sm-secondary">
              <i class="fas fa-eye"></i> View
            </a>
          {% endif %}
        </td>'''
    new_action_cell = '''<td>
          {% if o.status != 'completed' %}
            <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ o.id }}/" class="btn-sm-premium btn-sm-primary">
              <i class="fas fa-check-circle"></i> Complete
            </a>
          {% elif o.status == 'completed' and o.payment_status == 'partial' %}
            <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ o.id }}/" class="btn-sm-premium" style="background:#ffc107;color:#212529;">
              <i class="fas fa-hand-holding-usd"></i> Collect Pending
            </a>
          {% else %}
            <a href="/portal/{{ tenant.schema_name }}/chakki/order/{{ o.id }}/" class="btn-sm-premium btn-sm-secondary">
              <i class="fas fa-eye"></i> View
            </a>
          {% endif %}
        </td>'''
    if old_action_cell in content:
        content = content.replace(old_action_cell, new_action_cell)
        write_file(path, content)
        print("✅ Updated templates/desktop/order_list.html")
    else:
        print("⚠️ Could not find action cell in desktop/order_list.html. Skipping.")

    # 6. Mobile order_list.html
    path = 'templates/mobile/order_list.html'
    content = read_file(path)
    # Similar replacement.
    old_mobile_action = '''<td>
    {% if o.status != 'completed' %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ o.id }}/" class="btn btn-sm btn-primary">Complete</a>
    {% else %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/order/{{ o.id }}/" class="btn btn-sm btn-secondary">View</a>
    {% endif %}
</td>'''
    new_mobile_action = '''<td>
    {% if o.status != 'completed' %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ o.id }}/" class="btn btn-sm btn-primary">Complete</a>
    {% elif o.status == 'completed' and o.payment_status == 'partial' %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/complete-action/{{ o.id }}/" class="btn btn-sm btn-warning">Collect Pending</a>
    {% else %}
        <a href="/portal/{{ tenant.schema_name }}/chakki/order/{{ o.id }}/" class="btn btn-sm btn-secondary">View</a>
    {% endif %}
</td>'''
    if old_mobile_action in content:
        content = content.replace(old_mobile_action, new_mobile_action)
        write_file(path, content)
        print("✅ Updated templates/mobile/order_list.html")
    else:
        print("⚠️ Could not find action cell in mobile/order_list.html. Skipping.")

def patch_urls():
    # Not necessary to change URLs, but we can keep both.
    # The complete-partial now redirects via view, so it's fine.
    pass

def main():
    print("🚀 Applying order completion patches...")
    patch_views()
    patch_templates()
    print("✅ All patches applied! Please restart your server.")

if __name__ == '__main__':
    main()
