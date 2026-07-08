#!/usr/bin/env python3
"""
Patcher v2 – Settings UI overhaul
- Adds tabs (Grinding / Selling)
- Uses tables instead of cards
- Modal dialogs for adding categories
- Selling category add includes measurement + price
- Removes duplicate Manage button
"""

import os
import re

# ----- NEW VIEWS.PY (only the changed parts, but we'll replace the whole settings_view) -----
# Since we only need to modify the settings_view, we'll patch it instead of replacing the whole file.
# We'll read the existing views.py, find the settings_view function and replace it.

def patch_views():
    views_path = 'chakki/views.py'
    with open(views_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Define the new settings_view code (including the new action)
    new_settings_view = '''
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
                    price=price
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
            if cat_id and measurement and price:
                category = get_object_or_404(SellingCategory, id=cat_id, tenant=request.tenant)
                SellingPrice.objects.create(tenant=request.tenant, category=category, measurement=measurement, price=price)
                messages.success(request, f"Price added for {category.name} ({measurement})")
            else:
                messages.error(request, "All fields are required.")
            return redirect('chakki_settings', schema_name=request.tenant.schema_name)

        elif action == 'edit_selling_price':
            price_id = request.POST.get('selling_price_id')
            measurement = request.POST.get('measurement')
            price = request.POST.get('price')
            if price_id and measurement and price:
                selling_price = get_object_or_404(SellingPrice, id=price_id, tenant=request.tenant)
                selling_price.measurement = measurement
                selling_price.price = price
                selling_price.save()
                messages.success(request, "Price updated.")
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
'''

    # Find the existing settings_view function and replace it
    # We'll locate the start and end of the function using regex
    pattern = r'(@login_required\s*def settings_view\(request,\s*\*\*kwargs\):.*?)(?=\n@login_required|\ndef|\Z)'
    # We'll use re.DOTALL to match across lines
    # But we need to be careful: there might be other @login_required before it.
    # We'll search for the exact function signature.
    # Simpler: we'll replace the whole function body from the line "def settings_view" to the next function definition.
    # We'll use a more robust approach: find the index of "def settings_view" and then find the next "def " at the same indentation level.
    lines = content.splitlines()
    start_idx = None
    for i, line in enumerate(lines):
        if line.strip().startswith('def settings_view(request, **kwargs):'):
            start_idx = i
            break
    if start_idx is None:
        print("Could not find settings_view in views.py")
        return

    # Find the next def that starts at column 0 (top-level)
    end_idx = None
    for i in range(start_idx + 1, len(lines)):
        if lines[i].strip().startswith('def ') and not lines[i].startswith(' '):
            end_idx = i
            break
    if end_idx is None:
        end_idx = len(lines)

    # Replace the function with new code
    new_lines = new_settings_view.splitlines()
    # Remove the @login_required line from the new code if it exists (we'll keep the original decorator)
    # Actually we want to keep the decorator, so we'll just replace the function body.
    # We'll keep the decorator and function definition lines intact.
    # But our new code includes the decorator and definition; we'll just replace the whole block.
    # We'll construct the new block from the decorator to the end of function.
    # We'll find the decorator line before the function.
    # The original has "@login_required" line before def. We'll keep that.
    # We'll replace from def to end.
    # We'll just replace the entire function body from def onward.
    # We'll use the new code as is, but we need to ensure the indentation is correct.
    # Since our new code is indented with 0 spaces for the function definition, we'll keep it.

    # Write the new content
    new_content = '\n'.join(lines[:start_idx]) + '\n' + new_settings_view + '\n' + '\n'.join(lines[end_idx:])
    with open(views_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✅ Updated views.py with new settings_view including add_selling_category_with_price")

# ----- New desktop settings.html -----
DESKTOP_SETTINGS = '''{% extends "desktop/base.html" %}
{% block extra_head %}
<style>
    .settings-tabs .nav-link { color: var(--text); font-weight: 600; }
    .settings-tabs .nav-link.active { color: var(--accent); border-bottom-color: var(--accent); }
    .settings-tabs .nav-link:hover { border-color: var(--accent); }
    .table th { background: var(--surface-alt); }
    .modal-content { border-radius: var(--radius); }
    .modal-header { border-bottom: 1px solid var(--border); }
    .modal-footer { border-top: 1px solid var(--border); }
    .btn-sm { font-size: 0.75rem; }
    .action-btns .btn { margin-right: 0.2rem; }
</style>
{% endblock %}

{% block content %}
<div class="d-flex justify-content-between align-items-center mb-3">
    <h2>⚙️ Settings</h2>
</div>

<!-- Tabs -->
<ul class="nav nav-tabs settings-tabs" id="settingsTabs" role="tablist">
    <li class="nav-item" role="presentation">
        <button class="nav-link active" id="grinding-tab" data-bs-toggle="tab" data-bs-target="#grinding" type="button" role="tab">📦 Grinding Categories</button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link" id="selling-tab" data-bs-toggle="tab" data-bs-target="#selling" type="button" role="tab">🛒 Selling Items</button>
    </li>
</ul>

<div class="tab-content mt-3">
    <!-- Grinding Tab -->
    <div class="tab-pane fade show active" id="grinding" role="tabpanel">
        <div class="d-flex justify-content-between mb-2">
            <h5>Grinding Categories</h5>
            <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#addGrindingModal">+ Add Grinding Category</button>
        </div>
        <div class="table-responsive">
            <table class="table table-hover align-middle">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Description</th>
                        <th>Grinding Rate (per KG)</th>
                        <th>Cleaning Rate (per KG)</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    {% for cat in categories %}
                    <tr>
                        <td>{{ cat.name }}</td>
                        <td>{{ cat.description|default:"-" }}</td>
                        <td>₹{{ cat.grinding_rate }}</td>
                        <td>{% if cat.cleaning_rate %}₹{{ cat.cleaning_rate }}{% else %}—{% endif %}</td>
                        <td class="action-btns">
                            <button class="btn btn-outline-primary btn-sm" data-bs-toggle="modal" data-bs-target="#editGrindingModal{{ cat.id }}">Edit</button>
                            <form method="post" style="display:inline;" onsubmit="return confirm('Delete this category?');">
                                {% csrf_token %}
                                <input type="hidden" name="action" value="delete_category">
                                <input type="hidden" name="category_id" value="{{ cat.id }}">
                                <button type="submit" class="btn btn-outline-danger btn-sm">Delete</button>
                            </form>
                        </td>
                    </tr>
                    <!-- Edit Grinding Modal -->
                    <div class="modal fade" id="editGrindingModal{{ cat.id }}" tabindex="-1" aria-hidden="true">
                        <div class="modal-dialog">
                            <div class="modal-content">
                                <form method="post">
                                    {% csrf_token %}
                                    <input type="hidden" name="action" value="edit_category">
                                    <input type="hidden" name="category_id" value="{{ cat.id }}">
                                    <div class="modal-header">
                                        <h5 class="modal-title">Edit Grinding Category</h5>
                                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                    </div>
                                    <div class="modal-body">
                                        <div class="mb-2">
                                            <label>Name</label>
                                            <input type="text" name="category_name" class="form-control" value="{{ cat.name }}" required>
                                        </div>
                                        <div class="mb-2">
                                            <label>Description</label>
                                            <input type="text" name="category_description" class="form-control" value="{{ cat.description }}">
                                        </div>
                                        <div class="mb-2">
                                            <label>Grinding Rate (per KG)</label>
                                            <input type="number" name="grinding_rate" step="0.01" class="form-control" value="{{ cat.grinding_rate }}" required>
                                        </div>
                                        <div class="mb-2">
                                            <label>Cleaning Rate (per KG) – optional</label>
                                            <input type="number" name="cleaning_rate" step="0.01" class="form-control" value="{{ cat.cleaning_rate|default:'' }}" placeholder="Leave blank for none">
                                        </div>
                                    </div>
                                    <div class="modal-footer">
                                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                                        <button type="submit" class="btn btn-primary">Save Changes</button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                    {% empty %}
                    <tr><td colspan="5" class="text-center text-muted">No grinding categories added yet.</td></tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <!-- Selling Tab -->
    <div class="tab-pane fade" id="selling" role="tabpanel">
        <div class="d-flex justify-content-between mb-2">
            <h5>Selling Items (Prices per measurement)</h5>
            <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#addSellingModal">+ Add Selling Item</button>
        </div>
        <div class="table-responsive">
            <table class="table table-hover align-middle">
                <thead>
                    <tr>
                        <th>Category</th>
                        <th>Description</th>
                        <th>Measurement</th>
                        <th>Price</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    {% for cat in selling_categories %}
                        {% for price in cat.prices.all %}
                        <tr>
                            <td>{{ cat.name }}</td>
                            <td>{{ cat.description|default:"-" }}</td>
                            <td>{{ price.get_measurement_display }}</td>
                            <td>₹{{ price.price }}</td>
                            <td class="action-btns">
                                <button class="btn btn-outline-primary btn-sm" data-bs-toggle="modal" data-bs-target="#editSellingPriceModal{{ price.id }}">Edit Price</button>
                                <form method="post" style="display:inline;" onsubmit="return confirm('Delete this price?');">
                                    {% csrf_token %}
                                    <input type="hidden" name="action" value="delete_selling_price">
                                    <input type="hidden" name="selling_price_id" value="{{ price.id }}">
                                    <button type="submit" class="btn btn-outline-danger btn-sm">Delete</button>
                                </form>
                                <button class="btn btn-outline-secondary btn-sm" data-bs-toggle="modal" data-bs-target="#editSellingCatModal{{ cat.id }}">Edit Category</button>
                                <button class="btn btn-outline-success btn-sm" data-bs-toggle="modal" data-bs-target="#addSellingPriceModal{{ cat.id }}">+ Add Price</button>
                            </td>
                        </tr>
                        <!-- Edit Price Modal -->
                        <div class="modal fade" id="editSellingPriceModal{{ price.id }}" tabindex="-1" aria-hidden="true">
                            <div class="modal-dialog">
                                <div class="modal-content">
                                    <form method="post">
                                        {% csrf_token %}
                                        <input type="hidden" name="action" value="edit_selling_price">
                                        <input type="hidden" name="selling_price_id" value="{{ price.id }}">
                                        <div class="modal-header">
                                            <h5 class="modal-title">Edit Price</h5>
                                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                        </div>
                                        <div class="modal-body">
                                            <div class="mb-2">
                                                <label>Measurement</label>
                                                <select name="measurement" class="form-select">
                                                    <option value="kg" {% if price.measurement == 'kg' %}selected{% endif %}>KG</option>
                                                    <option value="liter" {% if price.measurement == 'liter' %}selected{% endif %}>Liter</option>
                                                    <option value="gram" {% if price.measurement == 'gram' %}selected{% endif %}>Gram</option>
                                                    <option value="packet" {% if price.measurement == 'packet' %}selected{% endif %}>Packet</option>
                                                    <option value="dozen" {% if price.measurement == 'dozen' %}selected{% endif %}>Dozen</option>
                                                    <option value="piece" {% if price.measurement == 'piece' %}selected{% endif %}>Piece</option>
                                                    <option value="bottle" {% if price.measurement == 'bottle' %}selected{% endif %}>Bottle</option>
                                                </select>
                                            </div>
                                            <div class="mb-2">
                                                <label>Price</label>
                                                <input type="number" name="price" step="0.01" class="form-control" value="{{ price.price }}" required>
                                            </div>
                                        </div>
                                        <div class="modal-footer">
                                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                                            <button type="submit" class="btn btn-primary">Save</button>
                                        </div>
                                    </form>
                                </div>
                            </div>
                        </div>
                        {% empty %}
                        <tr><td colspan="5" class="text-center text-muted">No selling items added yet.</td></tr>
                        {% endfor %}
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
</div>

<!-- Add Grinding Modal -->
<div class="modal fade" id="addGrindingModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="post">
                {% csrf_token %}
                <input type="hidden" name="action" value="add_category">
                <div class="modal-header">
                    <h5 class="modal-title">Add Grinding Category</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-2">
                        <label>Name *</label>
                        <input type="text" name="category_name" class="form-control" required>
                    </div>
                    <div class="mb-2">
                        <label>Description</label>
                        <input type="text" name="category_description" class="form-control">
                    </div>
                    <div class="mb-2">
                        <label>Grinding Rate (per KG) *</label>
                        <input type="number" name="grinding_rate" step="0.01" class="form-control" required>
                    </div>
                    <div class="mb-2">
                        <label>Cleaning Rate (per KG) – optional</label>
                        <input type="number" name="cleaning_rate" step="0.01" class="form-control" placeholder="Leave blank for none">
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Category</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Add Selling Category Modal (with measurement + price) -->
<div class="modal fade" id="addSellingModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="post">
                {% csrf_token %}
                <input type="hidden" name="action" value="add_selling_category_with_price">
                <div class="modal-header">
                    <h5 class="modal-title">Add Selling Item</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-2">
                        <label>Category Name *</label>
                        <input type="text" name="selling_category_name" class="form-control" required>
                    </div>
                    <div class="mb-2">
                        <label>Description</label>
                        <input type="text" name="selling_category_description" class="form-control">
                    </div>
                    <div class="mb-2">
                        <label>Measurement *</label>
                        <select name="measurement" class="form-select" required>
                            <option value="kg">KG</option>
                            <option value="liter">Liter</option>
                            <option value="gram">Gram</option>
                            <option value="packet">Packet</option>
                            <option value="dozen">Dozen</option>
                            <option value="piece">Piece</option>
                            <option value="bottle">Bottle</option>
                        </select>
                    </div>
                    <div class="mb-2">
                        <label>Price (per unit) *</label>
                        <input type="number" name="price" step="0.01" class="form-control" required>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Item</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Edit Selling Category Modal -->
{% for cat in selling_categories %}
<div class="modal fade" id="editSellingCatModal{{ cat.id }}" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="post">
                {% csrf_token %}
                <input type="hidden" name="action" value="edit_selling_category">
                <input type="hidden" name="selling_category_id" value="{{ cat.id }}">
                <div class="modal-header">
                    <h5 class="modal-title">Edit Selling Category</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-2">
                        <label>Name</label>
                        <input type="text" name="selling_category_name" class="form-control" value="{{ cat.name }}" required>
                    </div>
                    <div class="mb-2">
                        <label>Description</label>
                        <input type="text" name="selling_category_description" class="form-control" value="{{ cat.description }}">
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save</button>
                </div>
            </form>
        </div>
    </div>
</div>
{% endfor %}

<!-- Add Selling Price Modal (for existing category) -->
{% for cat in selling_categories %}
<div class="modal fade" id="addSellingPriceModal{{ cat.id }}" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="post">
                {% csrf_token %}
                <input type="hidden" name="action" value="add_selling_price">
                <input type="hidden" name="selling_category_id" value="{{ cat.id }}">
                <div class="modal-header">
                    <h5 class="modal-title">Add Price for {{ cat.name }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-2">
                        <label>Measurement</label>
                        <select name="measurement" class="form-select" required>
                            <option value="kg">KG</option>
                            <option value="liter">Liter</option>
                            <option value="gram">Gram</option>
                            <option value="packet">Packet</option>
                            <option value="dozen">Dozen</option>
                            <option value="piece">Piece</option>
                            <option value="bottle">Bottle</option>
                        </select>
                    </div>
                    <div class="mb-2">
                        <label>Price</label>
                        <input type="number" name="price" step="0.01" class="form-control" required>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Price</button>
                </div>
            </form>
        </div>
    </div>
</div>
{% endfor %}

{% endblock %}
'''

# ----- New mobile settings.html -----
MOBILE_SETTINGS = '''{% extends "mobile/base.html" %}
{% block extra_head %}
<style>
    .settings-tabs .nav-link { color: var(--text); font-weight: 600; }
    .settings-tabs .nav-link.active { color: var(--accent); border-bottom-color: var(--accent); }
    .settings-tabs .nav-link:hover { border-color: var(--accent); }
    .table th { background: var(--surface-alt); }
    .modal-content { border-radius: var(--radius); }
    .modal-header { border-bottom: 1px solid var(--border); }
    .modal-footer { border-top: 1px solid var(--border); }
    .btn-sm { font-size: 0.75rem; }
    .action-btns .btn { margin-right: 0.2rem; }
    .card-category { margin-bottom: 0.8rem; }
    .price-item { display: flex; justify-content: space-between; padding: 0.3rem 0; border-bottom: 1px solid var(--border); }
</style>
{% endblock %}

{% block body %}
<div class="d-flex justify-content-between align-items-center mb-3">
    <h5 class="fw-bold">⚙️ Settings</h5>
</div>

<!-- Tabs -->
<ul class="nav nav-tabs settings-tabs" id="settingsTabs" role="tablist">
    <li class="nav-item" role="presentation">
        <button class="nav-link active" id="grinding-tab" data-bs-toggle="tab" data-bs-target="#grinding" type="button" role="tab">📦 Grinding</button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link" id="selling-tab" data-bs-toggle="tab" data-bs-target="#selling" type="button" role="tab">🛒 Selling</button>
    </li>
</ul>

<div class="tab-content mt-3">
    <!-- Grinding Tab -->
    <div class="tab-pane fade show active" id="grinding" role="tabpanel">
        <div class="d-flex justify-content-between mb-2">
            <h6>Grinding Categories</h6>
            <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#addGrindingModal">+ Add</button>
        </div>
        {% for cat in categories %}
        <div class="card card-category p-3">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>{{ cat.name }}</strong>
                    <div class="text-muted small">{{ cat.description|default:"" }}</div>
                </div>
                <div>
                    <button class="btn btn-outline-primary btn-sm" data-bs-toggle="modal" data-bs-target="#editGrindingModal{{ cat.id }}">Edit</button>
                    <form method="post" style="display:inline;" onsubmit="return confirm('Delete this category?');">
                        {% csrf_token %}
                        <input type="hidden" name="action" value="delete_category">
                        <input type="hidden" name="category_id" value="{{ cat.id }}">
                        <button type="submit" class="btn btn-outline-danger btn-sm">Delete</button>
                    </form>
                </div>
            </div>
            <div class="row mt-2 text-center">
                <div class="col-6"><span class="text-muted">Grinding:</span> ₹{{ cat.grinding_rate }}/kg</div>
                <div class="col-6"><span class="text-muted">Cleaning:</span> {% if cat.cleaning_rate %}₹{{ cat.cleaning_rate }}/kg{% else %}—{% endif %}</div>
            </div>
        </div>
        <!-- Edit Grinding Modal -->
        <div class="modal fade" id="editGrindingModal{{ cat.id }}" tabindex="-1" aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="post">
                        {% csrf_token %}
                        <input type="hidden" name="action" value="edit_category">
                        <input type="hidden" name="category_id" value="{{ cat.id }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Edit Grinding Category</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-2">
                                <label>Name</label>
                                <input type="text" name="category_name" class="form-control" value="{{ cat.name }}" required>
                            </div>
                            <div class="mb-2">
                                <label>Description</label>
                                <input type="text" name="category_description" class="form-control" value="{{ cat.description }}">
                            </div>
                            <div class="mb-2">
                                <label>Grinding Rate (per KG)</label>
                                <input type="number" name="grinding_rate" step="0.01" class="form-control" value="{{ cat.grinding_rate }}" required>
                            </div>
                            <div class="mb-2">
                                <label>Cleaning Rate (per KG) – optional</label>
                                <input type="number" name="cleaning_rate" step="0.01" class="form-control" value="{{ cat.cleaning_rate|default:'' }}" placeholder="Leave blank for none">
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-primary">Save</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        {% empty %}
        <div class="text-muted text-center py-3">No grinding categories yet.</div>
        {% endfor %}
    </div>

    <!-- Selling Tab -->
    <div class="tab-pane fade" id="selling" role="tabpanel">
        <div class="d-flex justify-content-between mb-2">
            <h6>Selling Items</h6>
            <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#addSellingModal">+ Add</button>
        </div>
        {% for cat in selling_categories %}
        <div class="card card-category p-3">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>{{ cat.name }}</strong>
                    <div class="text-muted small">{{ cat.description|default:"" }}</div>
                </div>
                <div>
                    <button class="btn btn-outline-secondary btn-sm" data-bs-toggle="modal" data-bs-target="#editSellingCatModal{{ cat.id }}">Edit</button>
                    <form method="post" style="display:inline;" onsubmit="return confirm('Delete this category?');">
                        {% csrf_token %}
                        <input type="hidden" name="action" value="delete_selling_category">
                        <input type="hidden" name="selling_category_id" value="{{ cat.id }}">
                        <button type="submit" class="btn btn-outline-danger btn-sm">Delete</button>
                    </form>
                </div>
            </div>
            <div class="mt-2">
                <div class="d-flex justify-content-between align-items-center">
                    <span class="text-muted">Prices</span>
                    <button class="btn btn-outline-success btn-sm" data-bs-toggle="modal" data-bs-target="#addSellingPriceModal{{ cat.id }}">+ Add Price</button>
                </div>
                {% for price in cat.prices.all %}
                <div class="price-item">
                    <span>{{ price.get_measurement_display }}</span>
                    <span>₹{{ price.price }}</span>
                    <div>
                        <button class="btn btn-outline-primary btn-sm" data-bs-toggle="modal" data-bs-target="#editSellingPriceModal{{ price.id }}">Edit</button>
                        <form method="post" style="display:inline;" onsubmit="return confirm('Delete this price?');">
                            {% csrf_token %}
                            <input type="hidden" name="action" value="delete_selling_price">
                            <input type="hidden" name="selling_price_id" value="{{ price.id }}">
                            <button type="submit" class="btn btn-outline-danger btn-sm">Delete</button>
                        </form>
                    </div>
                </div>
                <!-- Edit Price Modal -->
                <div class="modal fade" id="editSellingPriceModal{{ price.id }}" tabindex="-1" aria-hidden="true">
                    <div class="modal-dialog">
                        <div class="modal-content">
                            <form method="post">
                                {% csrf_token %}
                                <input type="hidden" name="action" value="edit_selling_price">
                                <input type="hidden" name="selling_price_id" value="{{ price.id }}">
                                <div class="modal-header">
                                    <h5 class="modal-title">Edit Price</h5>
                                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                </div>
                                <div class="modal-body">
                                    <div class="mb-2">
                                        <label>Measurement</label>
                                        <select name="measurement" class="form-select">
                                            <option value="kg" {% if price.measurement == 'kg' %}selected{% endif %}>KG</option>
                                            <option value="liter" {% if price.measurement == 'liter' %}selected{% endif %}>Liter</option>
                                            <option value="gram" {% if price.measurement == 'gram' %}selected{% endif %}>Gram</option>
                                            <option value="packet" {% if price.measurement == 'packet' %}selected{% endif %}>Packet</option>
                                            <option value="dozen" {% if price.measurement == 'dozen' %}selected{% endif %}>Dozen</option>
                                            <option value="piece" {% if price.measurement == 'piece' %}selected{% endif %}>Piece</option>
                                            <option value="bottle" {% if price.measurement == 'bottle' %}selected{% endif %}>Bottle</option>
                                        </select>
                                    </div>
                                    <div class="mb-2">
                                        <label>Price</label>
                                        <input type="number" name="price" step="0.01" class="form-control" value="{{ price.price }}" required>
                                    </div>
                                </div>
                                <div class="modal-footer">
                                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                                    <button type="submit" class="btn btn-primary">Save</button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
                {% empty %}
                <div class="text-muted small">No prices defined.</div>
                {% endfor %}
            </div>
        </div>
        <!-- Edit Selling Category Modal -->
        <div class="modal fade" id="editSellingCatModal{{ cat.id }}" tabindex="-1" aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="post">
                        {% csrf_token %}
                        <input type="hidden" name="action" value="edit_selling_category">
                        <input type="hidden" name="selling_category_id" value="{{ cat.id }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Edit Selling Category</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-2">
                                <label>Name</label>
                                <input type="text" name="selling_category_name" class="form-control" value="{{ cat.name }}" required>
                            </div>
                            <div class="mb-2">
                                <label>Description</label>
                                <input type="text" name="selling_category_description" class="form-control" value="{{ cat.description }}">
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-primary">Save</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        <!-- Add Selling Price Modal (for existing category) -->
        <div class="modal fade" id="addSellingPriceModal{{ cat.id }}" tabindex="-1" aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="post">
                        {% csrf_token %}
                        <input type="hidden" name="action" value="add_selling_price">
                        <input type="hidden" name="selling_category_id" value="{{ cat.id }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Add Price for {{ cat.name }}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-2">
                                <label>Measurement</label>
                                <select name="measurement" class="form-select" required>
                                    <option value="kg">KG</option>
                                    <option value="liter">Liter</option>
                                    <option value="gram">Gram</option>
                                    <option value="packet">Packet</option>
                                    <option value="dozen">Dozen</option>
                                    <option value="piece">Piece</option>
                                    <option value="bottle">Bottle</option>
                                </select>
                            </div>
                            <div class="mb-2">
                                <label>Price</label>
                                <input type="number" name="price" step="0.01" class="form-control" required>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-primary">Add Price</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        {% empty %}
        <div class="text-muted text-center py-3">No selling items yet.</div>
        {% endfor %}
    </div>
</div>

<!-- Add Grinding Modal -->
<div class="modal fade" id="addGrindingModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="post">
                {% csrf_token %}
                <input type="hidden" name="action" value="add_category">
                <div class="modal-header">
                    <h5 class="modal-title">Add Grinding Category</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-2">
                        <label>Name *</label>
                        <input type="text" name="category_name" class="form-control" required>
                    </div>
                    <div class="mb-2">
                        <label>Description</label>
                        <input type="text" name="category_description" class="form-control">
                    </div>
                    <div class="mb-2">
                        <label>Grinding Rate (per KG) *</label>
                        <input type="number" name="grinding_rate" step="0.01" class="form-control" required>
                    </div>
                    <div class="mb-2">
                        <label>Cleaning Rate (per KG) – optional</label>
                        <input type="number" name="cleaning_rate" step="0.01" class="form-control" placeholder="Leave blank for none">
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Add Selling Category Modal (with measurement + price) -->
<div class="modal fade" id="addSellingModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="post">
                {% csrf_token %}
                <input type="hidden" name="action" value="add_selling_category_with_price">
                <div class="modal-header">
                    <h5 class="modal-title">Add Selling Item</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-2">
                        <label>Category Name *</label>
                        <input type="text" name="selling_category_name" class="form-control" required>
                    </div>
                    <div class="mb-2">
                        <label>Description</label>
                        <input type="text" name="selling_category_description" class="form-control">
                    </div>
                    <div class="mb-2">
                        <label>Measurement *</label>
                        <select name="measurement" class="form-select" required>
                            <option value="kg">KG</option>
                            <option value="liter">Liter</option>
                            <option value="gram">Gram</option>
                            <option value="packet">Packet</option>
                            <option value="dozen">Dozen</option>
                            <option value="piece">Piece</option>
                            <option value="bottle">Bottle</option>
                        </select>
                    </div>
                    <div class="mb-2">
                        <label>Price (per unit) *</label>
                        <input type="number" name="price" step="0.01" class="form-control" required>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add</button>
                </div>
            </form>
        </div>
    </div>
</div>

{% endblock %}
'''

# ----- Fix duplicate Manage button in mobile chakki.html -----
def fix_duplicate_manage():
    filepath = 'templates/mobile/chakki.html'
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    # The duplicate manage appears as two consecutive <a> tags with class "btn-secondary btn-sm ms-2"
    # We'll replace with a single one.
    # Find the line with "Manage" and remove one.
    # We'll look for the pattern: <a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="btn btn-primary-custom btn-sm">+ New</a> <a href="/portal/{{ tenant.schema_name }}/chakki/settings/" class="btn btn-secondary btn-sm ms-2">Manage</a> <a href="/portal/{{ tenant.schema_name }}/chakki/settings/" class="btn btn-secondary btn-sm ms-2">Manage</a>
    # We'll replace with single manage.
    pattern = r'(<a href="/portal/{{ tenant\.schema_name }}/chakki/add/" class="btn btn-primary-custom btn-sm">\+ New</a>)\s*<a href="/portal/{{ tenant\.schema_name }}/chakki/settings/" class="btn btn-secondary btn-sm ms-2">Manage</a>\s*<a href="/portal/{{ tenant\.schema_name }}/chakki/settings/" class="btn btn-secondary btn-sm ms-2">Manage</a>'
    replacement = r'\1 <a href="/portal/{{ tenant.schema_name }}/chakki/settings/" class="btn btn-secondary btn-sm ms-2">Manage</a>'
    content = re.sub(pattern, replacement, content)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Fixed duplicate Manage button in mobile chakki.html")

def main():
    print("🚀 Applying Settings UI patch...")
    
    # Patch views.py
    patch_views()
    
    # Write desktop settings
    with open('templates/desktop/settings.html', 'w', encoding='utf-8') as f:
        f.write(DESKTOP_SETTINGS)
    print("✅ Updated desktop settings.html")
    
    # Write mobile settings
    with open('templates/mobile/settings.html', 'w', encoding='utf-8') as f:
        f.write(MOBILE_SETTINGS)
    print("✅ Updated mobile settings.html")
    
    # Fix duplicate Manage button
    fix_duplicate_manage()
    
    print("\n✅ All patches applied successfully!")
    print("\n📌 Next steps:")
    print("   1. python3 manage.py migrate tenants 0006 --fake   # (fix previous tenant migration error)")
    print("   2. python3 manage.py migrate")
    print("   3. Restart your server and test the new Settings UI.")
    print("   - Tabs: Grinding / Selling")
    print("   - Add forms in modals")
    print("   - Tables instead of cards (desktop)")
    print("   - Selling category add now includes measurement + price")

if __name__ == '__main__':
    main()
