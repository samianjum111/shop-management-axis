#!/usr/bin/env python3
"""
Add a click handler for the modal close (X) button.
Run once: python3 fix_close_button.py
"""

import os
import re

FILES = [
    "templates/mobile/add_order_form.html",
    "templates/desktop/add_order_form.html",
]

# The new script block with the close button handler added.
NEW_SCRIPT = """<script>
let itemCount = 1;
const container = document.getElementById('itemsContainer');
const addBtn = document.getElementById('addItemBtn');
const totalGrindingDisplay = document.getElementById('total_grinding_display');
const totalCleaningDisplay = document.getElementById('total_cleaning_display');
const grandTotalDisplay = document.getElementById('grand_total_display');
const modalBody = document.getElementById('modalBody');
const confirmSubmit = document.getElementById('confirmSubmit');
const itemCountInput = document.getElementById('item_count');
const paymentTypeInput = document.getElementById('payment_type');
const partialAmountDiv = document.getElementById('partial_amount_div');
const paymentAmountInput = document.getElementById('payment_amount');
const remainingDisplay = document.getElementById('remaining_display');
const pendingRow = document.getElementById('pending_row');
const walkinName = document.getElementById('walkin_name');
const walkinPhone = document.getElementById('walkin_phone');
const grindRate = {{ setting.grinding_rate }};
const cleanRate = {{ setting.cleaning_rate }};

function updateTotals() {
    let totalGrinding = 0, totalCleaning = 0;
    document.querySelectorAll('.item-row').forEach(row => {
        const kg = parseFloat(row.querySelector('.total-kg').value) || 0;
        const cleaning = row.querySelector('input[type="checkbox"]').checked;
        totalGrinding += kg * grindRate;
        if (cleaning) totalCleaning += kg * cleanRate;
    });
    const grandTotal = totalGrinding + totalCleaning;
    totalGrindingDisplay.textContent = '₹' + totalGrinding.toFixed(2);
    totalCleaningDisplay.textContent = '₹' + totalCleaning.toFixed(2);
    grandTotalDisplay.textContent = '₹' + grandTotal.toFixed(2);
    window._totals = { grinding: totalGrinding, cleaning: totalCleaning, grand: grandTotal };
    updateRemaining();
}

function updateRemaining() {
    const grand = window._totals ? window._totals.grand : 0;
    const paid = parseFloat(paymentAmountInput.value) || 0;
    const remaining = Math.max(0, grand - paid);
    remainingDisplay.textContent = 'Remaining: ₹' + remaining.toFixed(2);
}

function setPayment(type) {
    document.querySelectorAll('.payment-toggle .btn-option').forEach(el => el.classList.remove('active'));
    document.querySelector(`.payment-toggle .btn-option[data-value="${type}"]`).classList.add('active');
    paymentTypeInput.value = type;
    if (type === 'partial') {
        partialAmountDiv.classList.add('show');
        if (walkinPhone) walkinPhone.required = true;
        if (walkinName) walkinName.required = true;
    } else {
        partialAmountDiv.classList.remove('show');
        if (walkinPhone) walkinPhone.required = false;
        if (walkinName) walkinName.required = true;
    }
    updateRemaining();
}

function addItemRow() {
    itemCount++;
    const newRow = document.createElement('div');
    newRow.className = 'row item-row g-2 mb-2';
    newRow.innerHTML = `
        <div class="col-md-4">
            <select name="category_${itemCount}" class="form-select category-select">
                <option value="">Select Category</option>
                {% for cat in categories %}
                <option value="{{ cat.id }}">{{ cat.name }}</option>
                {% endfor %}
            </select>
        </div>
        <div class="col-md-3">
            <input type="number" name="total_kg_${itemCount}" class="form-control total-kg" step="0.1" placeholder="KG" value="0">
        </div>
        <div class="col-md-2">
            <div class="form-check">
                <input type="checkbox" name="cleaning_${itemCount}" value="on" class="form-check-input">
                <label class="form-check-label">Cleaning</label>
            </div>
        </div>
        <div class="col-md-3">
            <button type="button" class="btn btn-danger btn-sm remove-item">Remove</button>
        </div>
    `;
    container.appendChild(newRow);
    itemCountInput.value = itemCount;
    // Attach events for the new row
    newRow.querySelector('.total-kg').addEventListener('input', updateTotals);
    newRow.querySelector('input[type="checkbox"]').addEventListener('change', updateTotals);
    newRow.querySelector('.remove-item').addEventListener('click', function() {
        if (container.children.length > 1) {
            newRow.remove();
            itemCount--;
            itemCountInput.value = itemCount;
            updateTotals();
        }
    });
}

function showPreviewModal() {
    const totals = window._totals || { grinding: 0, cleaning: 0, grand: 0 };
    const customerName = document.querySelector('input[name="name"]')?.value || '{{ customer.name|default:"N/A" }}';
    const customerPhone = document.querySelector('input[name="phone"]')?.value || '{{ customer.phone|default:"N/A" }}';
    const paymentType = paymentTypeInput.value;
    let paymentAmount = 0;
    if (paymentType === 'partial') {
        paymentAmount = parseFloat(paymentAmountInput.value) || 0;
    } else {
        paymentAmount = totals.grand;
    }
    let itemsHtml = '';
    document.querySelectorAll('.item-row').forEach(row => {
        const category = row.querySelector('.category-select').options[row.querySelector('.category-select').selectedIndex]?.text || 'N/A';
        const kg = row.querySelector('.total-kg').value || 0;
        const cleaning = row.querySelector('input[type="checkbox"]').checked ? 'Yes' : 'No';
        itemsHtml += `<p><strong>${category}</strong> - ${kg}kg, Cleaning: ${cleaning}</p>`;
    });
    modalBody.innerHTML = `
        <p><strong>Customer:</strong> ${customerName} (${customerPhone})</p>
        <hr>
        <h6>Items:</h6>
        ${itemsHtml}
        <hr>
        <p><strong>Grinding Total:</strong> ₹${totals.grinding.toFixed(2)}</p>
        <p><strong>Cleaning Total:</strong> ₹${totals.cleaning.toFixed(2)}</p>
        <h5><strong>Grand Total:</strong> ₹${totals.grand.toFixed(2)}</h5>
        <p><strong>Payment Type:</strong> ${paymentType.charAt(0).toUpperCase() + paymentType.slice(1)}</p>
        <p><strong>Amount Paid:</strong> ₹${paymentAmount.toFixed(2)}</p>
        <p><strong>Remaining:</strong> ₹${(totals.grand - paymentAmount).toFixed(2)}</p>
        {% if not customer %}
        <p class="text-muted small">After order, you can add this customer to regulars.</p>
        {% endif %}
    `;
    // Show modal
    var modalEl = document.getElementById('confirmModal');
    if (modalEl) {
        if (typeof bootstrap !== 'undefined' && bootstrap.Modal) {
            var modal = new bootstrap.Modal(modalEl);
            modal.show();
        } else {
            // Manual fallback
            modalEl.style.display = 'block';
            modalEl.classList.add('show');
            document.body.classList.add('modal-open');
            if (!document.querySelector('.modal-backdrop')) {
                var backdrop = document.createElement('div');
                backdrop.className = 'modal-backdrop fade show';
                document.body.appendChild(backdrop);
            }
        }
    } else {
        alert('Modal element not found.');
    }
}

// ---- DOM Ready ----
document.addEventListener('DOMContentLoaded', function() {
    // Existing items
    document.querySelectorAll('.total-kg').forEach(el => el.addEventListener('input', updateTotals));
    document.querySelectorAll('input[type="checkbox"]').forEach(el => el.addEventListener('change', updateTotals));
    // Existing remove buttons
    document.querySelectorAll('.remove-item').forEach(btn => {
        btn.addEventListener('click', function() {
            const row = this.closest('.item-row');
            if (row && container.children.length > 1) {
                row.remove();
                itemCount--;
                itemCountInput.value = itemCount;
                updateTotals();
            }
        });
    });
    // Cancel button
    var cancelBtn = document.getElementById('cancelModalBtn');
    if (cancelBtn) {
        cancelBtn.addEventListener('click', function() {
            var modalEl = document.getElementById('confirmModal');
            if (modalEl) {
                if (typeof bootstrap !== 'undefined' && bootstrap.Modal) {
                    var modal = bootstrap.Modal.getInstance(modalEl);
                    if (modal) modal.hide();
                    else {
                        modalEl.style.display = 'none';
                        modalEl.classList.remove('show');
                        document.body.classList.remove('modal-open');
                        var backdrop = document.querySelector('.modal-backdrop');
                        if (backdrop) backdrop.remove();
                    }
                } else {
                    modalEl.style.display = 'none';
                    modalEl.classList.remove('show');
                    document.body.classList.remove('modal-open');
                    var backdrop = document.querySelector('.modal-backdrop');
                    if (backdrop) backdrop.remove();
                }
            }
        });
    }
    // Close button (X) in modal header
    var closeBtn = document.querySelector('#confirmModal .btn-close');
    if (closeBtn) {
        closeBtn.addEventListener('click', function() {
            var modalEl = document.getElementById('confirmModal');
            if (modalEl) {
                if (typeof bootstrap !== 'undefined' && bootstrap.Modal) {
                    var modal = bootstrap.Modal.getInstance(modalEl);
                    if (modal) modal.hide();
                    else {
                        modalEl.style.display = 'none';
                        modalEl.classList.remove('show');
                        document.body.classList.remove('modal-open');
                        var backdrop = document.querySelector('.modal-backdrop');
                        if (backdrop) backdrop.remove();
                    }
                } else {
                    modalEl.style.display = 'none';
                    modalEl.classList.remove('show');
                    document.body.classList.remove('modal-open');
                    var backdrop = document.querySelector('.modal-backdrop');
                    if (backdrop) backdrop.remove();
                }
            }
        });
    }
    // Add item button
    addBtn.addEventListener('click', addItemRow);
    // Payment amount input
    paymentAmountInput.addEventListener('input', updateRemaining);
    // Confirm submit
    confirmSubmit.addEventListener('click', function() {
        document.getElementById('orderForm').submit();
    });
    // Initial calculation
    updateTotals();
});
</script>"""

def patch_file(filepath):
    if not os.path.isfile(filepath):
        print(f"⚠️  File not found: {filepath}")
        return False

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace the entire <script> block
    pattern = r'(<script>).*?(</script>)'
    new_content = re.sub(pattern, NEW_SCRIPT, content, flags=re.DOTALL)
    if new_content == content:
        print(f"⚠️  Could not replace script in {filepath}")
        return False

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"✅ Patched {filepath}")
    return True

def main():
    print("🔧 Adding close (X) button handler to modal...")
    for f in FILES:
        patch_file(f)
    print("✅ Done. Restart Django server and test the X button.")

if __name__ == "__main__":
    main()
