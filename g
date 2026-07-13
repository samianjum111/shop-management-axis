#!/usr/bin/env python3
import re
from pathlib import Path

# The corrected JavaScript block (for both templates)
CORRECTED_SCRIPT = """
<script>
    function setPayment(val) {
        document.querySelectorAll('.payment-toggle .btn-option').forEach(el => el.classList.remove('active'));
        document.querySelector(`.payment-toggle .btn-option[data-value="${val}"]`).classList.add('active');
        document.getElementById('payment_type').value = val;
        var div = document.getElementById('partial_amount_div');
        var amountInput = document.getElementById('payment_amount');
        if (val === 'partial') {
            div.style.display = 'block';
            if (amountInput) amountInput.setAttribute('required', 'required');
        } else {
            div.style.display = 'none';
            if (amountInput) amountInput.removeAttribute('required');
        }
        if (typeof updateRemaining === 'function') {
            updateRemaining();
        }
    }

    document.addEventListener('DOMContentLoaded', function() {
        setPayment('full');
        // payment amount live update
        var amountInput = document.getElementById('payment_amount');
        if (amountInput) {
            amountInput.addEventListener('input', function() {
                if (typeof updateRemaining === 'function') updateRemaining();
            });
        }
        // initialize totals
        updateTotals();
    });

    // ---- Core logic ----
    let itemCount = 1;
    const container = document.getElementById('itemsContainer');
    const addBtn = document.getElementById('addItemBtn');
    const totalGrindingDisplay = document.getElementById('total_grinding_display');
    const totalCleaningDisplay = document.getElementById('total_cleaning_display');
    const totalSellingDisplay = document.getElementById('total_selling_display');
    const grandTotalDisplay = document.getElementById('grand_total_display');
    const previewBtn = document.getElementById('previewBtn');
    const modalBody = document.getElementById('modalBody');
    const confirmSubmit = document.getElementById('confirmSubmit');
    const itemCountInput = document.getElementById('item_count');
    const submitSpinner = document.getElementById('submitSpinner');

    function updateTotals() {
        let totalGrinding = 0, totalCleaning = 0, totalSelling = 0;
        document.querySelectorAll('.item-card').forEach(row => {
            const itemType = row.querySelector('.item-type-select').value;
            if (itemType === 'grinding') {
                const kg = parseFloat(row.querySelector('.total-kg').value) || 0;
                const cleaning = row.querySelector('input[type="checkbox"]').checked;
                const catSelect = row.querySelector('.category-select');
                const selectedOption = catSelect.options[catSelect.selectedIndex];
                const grindRate = parseFloat(selectedOption.getAttribute('data-grind-rate')) || 0;
                const cleanRate = parseFloat(selectedOption.getAttribute('data-clean-rate')) || 0;
                totalGrinding += kg * grindRate;
                if (cleaning) totalCleaning += kg * cleanRate;
            } else if (itemType === 'selling') {
                const qty = parseFloat(row.querySelector('.quantity').value) || 0;
                const priceSelect = row.querySelector('.selling-price-select');
                const price = parseFloat(priceSelect.options[priceSelect.selectedIndex]?.getAttribute('data-price')) || 0;
                totalSelling += qty * price;
            }
        });
        const grandTotal = totalGrinding + totalCleaning + totalSelling;
        totalGrindingDisplay.textContent = '₹' + totalGrinding.toFixed(2);
        totalCleaningDisplay.textContent = '₹' + totalCleaning.toFixed(2);
        totalSellingDisplay.textContent = '₹' + totalSelling.toFixed(2);
        grandTotalDisplay.textContent = '₹' + grandTotal.toFixed(2);
        window._totals = { grinding: totalGrinding, cleaning: totalCleaning, selling: totalSelling, grand: grandTotal };
        updateRemaining();
    }

    function updateRemaining() {
        const grand = window._totals ? window._totals.grand : 0;
        const paid = parseFloat(document.getElementById('payment_amount')?.value) || 0;
        const remaining = Math.max(0, grand - paid);
        const display = document.getElementById('remaining_display');
        if (display) display.textContent = 'Remaining: ₹' + remaining.toFixed(2);
    }

    function fetchPrices(selectEl) {
        const catId = selectEl.value;
        const row = selectEl.closest('.item-card');
        const priceSelect = row.querySelector('.selling-price-select');
        priceSelect.innerHTML = '<option value="">Select Measurement</option>';
        if (catId) {
            fetch(`/portal/{{ tenant.schema_name }}/chakki/api/selling-prices/?category=${catId}`)
                .then(response => response.json())
                .then(data => {
                    data.forEach(item => {
                        const opt = document.createElement('option');
                        opt.value = item.id;
                        opt.textContent = item.measurement + ' - ₹' + item.price + ' (Stock: ' + item.stock + ')';
                        opt.setAttribute('data-price', item.price);
                        opt.setAttribute('data-stock', item.stock);
                        opt.setAttribute('data-measurement', item.measurement);
                        priceSelect.appendChild(opt);
                    });
                })
                .catch(err => console.error(err));
        }
    }

    function toggleFields(row) {
        const type = row.querySelector('.item-type-select').value;
        const grindingFields = row.querySelectorAll('.grinding-fields');
        const sellingFields = row.querySelectorAll('.selling-fields');
        if (type === 'grinding') {
            grindingFields.forEach(el => el.style.display = '');
            sellingFields.forEach(el => el.style.display = 'none');
        } else {
            grindingFields.forEach(el => el.style.display = 'none');
            sellingFields.forEach(el => el.style.display = '');
        }
        updateTotals();
    }

    function addItemRow() {
        itemCount++;
        const rowId = 'itemRow' + itemCount;
        const template = `
            <div class="item-card item-card-enter" id="${rowId}">
                <div class="row g-2 align-items-end">
                    <div class="col-12 col-sm-2">
                        <select name="item_type_${itemCount}" class="form-control-sm-custom item-type-select">
                            <option value="grinding">Grinding</option>
                            <option value="selling">Selling</option>
                        </select>
                    </div>
                    <div class="col-12 col-sm-4 grinding-fields">
                        <select name="category_${itemCount}" class="form-control-sm-custom category-select">
                            <option value="">Select Grinding Category</option>
                            {% for cat in categories %}
                            <option value="{{ cat.id }}" data-grind-rate="{{ cat.grinding_rate }}" data-clean-rate="{{ cat.cleaning_rate|default:0 }}">{{ cat.name }}</option>
                            {% endfor %}
                        </select>
                    </div>
                    <div class="col-6 col-sm-3 grinding-fields">
                        <input type="number" name="total_kg_${itemCount}" class="form-control-sm-custom total-kg" step="0.1" placeholder="KG" value="0" min="0">
                    </div>
                    <div class="col-4 col-sm-2 grinding-fields d-flex align-items-center">
                        <input type="checkbox" name="cleaning_${itemCount}" id="cleaning_${itemCount}" value="on" class="form-check-input me-1">
                        <label for="cleaning_${itemCount}" class="form-label small mb-0">Cleaning</label>
                    </div>
                    <div class="col-12 col-sm-5 selling-fields" style="display:none;">
                        <select name="selling_category_${itemCount}" class="form-control-sm-custom selling-category-select">
                            <option value="">Select Selling Category</option>
                            {% for cat in selling_categories %}
                            <option value="{{ cat.id }}">{{ cat.name }}</option>
                            {% endfor %}
                        </select>
                    </div>
                    <div class="col-6 col-sm-3 selling-fields" style="display:none;">
                        <select name="selling_price_${itemCount}" class="form-control-sm-custom selling-price-select">
                            <option value="">Measurement</option>
                        </select>
                    </div>
                    <div class="col-4 col-sm-2 selling-fields" style="display:none;">
                        <input type="number" name="quantity_${itemCount}" class="form-control-sm-custom quantity" step="0.1" placeholder="Qty" value="0" min="0">
                    </div>
                    <div class="col-2 text-end">
                        <button type="button" class="remove-item" title="Remove item"><i class="fas fa-trash-alt"></i></button>
                    </div>
                </div>
            </div>
        `;
        const wrapper = document.createElement('div');
        wrapper.innerHTML = template.trim();
        const newRow = wrapper.firstElementChild;
        container.appendChild(newRow);
        itemCountInput.value = itemCount;
        // bind events
        attachEvents(newRow);
        toggleFields(newRow);
        updateTotals();
    }

    function attachEvents(row) {
        row.querySelector('.item-type-select').addEventListener('change', function() { toggleFields(row); });
        row.querySelector('.selling-category-select').addEventListener('change', function() { fetchPrices(this); });
        row.querySelectorAll('.total-kg, .quantity, input[type="checkbox"]').forEach(el => el.addEventListener('input', updateTotals));
        row.querySelector('.remove-item').addEventListener('click', function() {
            if (document.querySelectorAll('.item-card').length > 1) {
                row.remove();
                itemCount--;
                itemCountInput.value = itemCount;
                updateTotals();
            }
        });
    }

    // Initial bind for existing rows
    document.querySelectorAll('.item-card').forEach(row => attachEvents(row));

    addBtn.addEventListener('click', addItemRow);

    // Preview & Confirm
    previewBtn.addEventListener('click', function() {
        if (!validateOrder()) return;
        const totals = window._totals || { grand: 0 };
        const customerName = document.querySelector('input[name="name"]')?.value || '{{ customer.name|default:"N/A" }}';
        let itemsHtml = '';
        document.querySelectorAll('.item-card').forEach(row => {
            const type = row.querySelector('.item-type-select').value;
            if (type === 'grinding') {
                const cat = row.querySelector('.category-select').options[row.querySelector('.category-select').selectedIndex]?.text || 'N/A';
                const kg = row.querySelector('.total-kg').value || 0;
                const cleaning = row.querySelector('input[type="checkbox"]').checked ? 'Yes' : 'No';
                itemsHtml += `<div class="d-flex justify-content-between border-bottom py-1"><span><strong>${cat}</strong> (Grinding)</span><span>${kg}kg, Cleaning: ${cleaning}</span></div>`;
            } else {
                const cat = row.querySelector('.selling-category-select').options[row.querySelector('.selling-category-select').selectedIndex]?.text || 'N/A';
                const meas = row.querySelector('.selling-price-select').options[row.querySelector('.selling-price-select').selectedIndex]?.text || 'N/A';
                const qty = row.querySelector('.quantity').value || 0;
                itemsHtml += `<div class="d-flex justify-content-between border-bottom py-1"><span><strong>${cat}</strong> (Selling)</span><span>${qty} ${meas}</span></div>`;
            }
        });
        const paymentType = document.getElementById('payment_type').value;
        let paymentAmount = 0;
        if (paymentType === 'partial') {
            paymentAmount = parseFloat(document.getElementById('payment_amount').value) || 0;
        } else {
            paymentAmount = totals.grand;
        }
        modalBody.innerHTML = `
            <div class="mb-3"><i class="fas fa-user"></i> <strong>Customer:</strong> ${customerName}</div>
            <h6 class="border-bottom pb-1">Items</h6>
            ${itemsHtml}
            <hr>
            <div class="d-flex justify-content-between"><span>Grinding Total</span><span>₹${totals.grinding.toFixed(2)}</span></div>
            <div class="d-flex justify-content-between"><span>Cleaning Total</span><span>₹${totals.cleaning.toFixed(2)}</span></div>
            <div class="d-flex justify-content-between"><span>Selling Total</span><span>₹${totals.selling.toFixed(2)}</span></div>
            <div class="d-flex justify-content-between fw-bold fs-5 mt-2"><span>Grand Total</span><span>₹${totals.grand.toFixed(2)}</span></div>
            <hr>
            <div class="d-flex justify-content-between"><span>Payment Type</span><span class="badge bg-secondary">${paymentType.charAt(0).toUpperCase() + paymentType.slice(1)}</span></div>
            <div class="d-flex justify-content-between"><span>Amount Paid</span><span>₹${paymentAmount.toFixed(2)}</span></div>
            <div class="d-flex justify-content-between"><span>Remaining</span><span class="fw-bold">₹${(totals.grand - paymentAmount).toFixed(2)}</span></div>
        `;
        var modalEl = document.getElementById('confirmModal');
        if (modalEl) {
            if (typeof bootstrap !== 'undefined' && bootstrap.Modal) {
                var modal = new bootstrap.Modal(modalEl);
                modal.show();
            } else {
                // fallback
                modalEl.style.display = 'block';
                modalEl.classList.add('show');
                document.body.classList.add('modal-open');
                if (!document.querySelector('.modal-backdrop')) {
                    var backdrop = document.createElement('div');
                    backdrop.className = 'modal-backdrop fade show';
                    document.body.appendChild(backdrop);
                }
            }
        }
    });

    confirmSubmit.addEventListener('click', function() {
        // show spinner
        submitSpinner.classList.add('active');
        document.getElementById('orderForm').submit();
    });

    function validateOrder() {
        let errors = [];
        const customerId = document.querySelector('input[name="customer_id"]')?.value;
        if (!customerId) {
            const name = document.querySelector('input[name="name"]')?.value.trim();
            if (!name) errors.push('Name is required for walk-in customer.');
        }
        const paymentType = document.getElementById('payment_type').value;
        if (paymentType === 'partial' && !customerId) {
            const phone = document.getElementById('walkin_phone')?.value.trim();
            if (!phone) errors.push('Phone is required for partial payment for walk-in customers.');
        }
        let hasItem = false;
        document.querySelectorAll('.item-card').forEach(row => {
            const type = row.querySelector('.item-type-select').value;
            if (type === 'grinding') {
                const cat = row.querySelector('.category-select').value;
                const kg = parseFloat(row.querySelector('.total-kg').value) || 0;
                if (cat && kg > 0) hasItem = true;
            } else {
                const price = row.querySelector('.selling-price-select').value;
                const qty = parseFloat(row.querySelector('.quantity').value) || 0;
                if (price && qty > 0) hasItem = true;
            }
        });
        // stock check
        document.querySelectorAll('.item-card').forEach(row => {
            const itemType = row.querySelector('.item-type-select').value;
            if (itemType === 'selling') {
                const priceSelect = row.querySelector('.selling-price-select');
                const selectedOption = priceSelect.options[priceSelect.selectedIndex];
                if (selectedOption && selectedOption.value) {
                    const stock = parseFloat(selectedOption.getAttribute('data-stock')) || 0;
                    const qty = parseFloat(row.querySelector('.quantity').value) || 0;
                    if (qty > stock) {
                        const categorySelect = row.querySelector('.selling-category-select');
                        const categoryName = categorySelect.options[categorySelect.selectedIndex]?.text || 'Unknown';
                        const measurement = selectedOption.getAttribute('data-measurement') || '';
                        errors.push(`Insufficient stock for "${categoryName}". Available: ${stock} ${measurement}`);
                    }
                }
            }
        });
        if (!hasItem) errors.push('Please add at least one valid item.');
        const errorDiv = document.getElementById('formErrors');
        if (errors.length > 0) {
            errorDiv.style.display = 'block';
            errorDiv.innerHTML = errors.join('<br>');
            errorDiv.scrollIntoView({ behavior: 'smooth', block: 'center' });
            return false;
        } else {
            errorDiv.style.display = 'none';
            return true;
        }
    }
</script>
"""

def patch_template(template_path):
    if not template_path.exists():
        print(f"⚠️ Template not found: {template_path}")
        return False

    with open(template_path, 'r') as f:
        content = f.read()

    # Find the existing <script> block and replace it
    # We'll search for the opening <script> tag with the JavaScript content.
    # Use a pattern that matches from <script> to </script>
    pattern = r'<script>.*?</script>'
    # We'll replace the entire block, but we need to keep any template variables that might be inside.
    # However, the corrected script uses Django template variables like {{ tenant.schema_name }}, so we need to keep them.
    # We'll just replace the content between <script> and </script>.
    # Find the existing script content.
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print(f"⚠️ No script block found in {template_path}")
        return False

    # Replace the script block with the corrected one
    new_content = re.sub(pattern, CORRECTED_SCRIPT, content, flags=re.DOTALL)

    # Write back
    with open(template_path, 'w') as f:
        f.write(new_content)

    print(f"✅ Patched {template_path}")
    return True

def main():
    templates = [
        Path(__file__).parent / 'templates' / 'mobile' / 'add_order_form.html',
        Path(__file__).parent / 'templates' / 'desktop' / 'add_order_form.html',
    ]
    for template in templates:
        patch_template(template)

    print("\n✅ Done! The partial toggle and validation are fixed.")
    print("📌 Restart your Django server and test again.")

if __name__ == "__main__":
    main()
