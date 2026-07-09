#!/usr/bin/env python3
"""
Upgrade mobile/add_order_customer_list.html with professional UI/UX.
Replaces extra_head and body blocks.
"""
import re
from pathlib import Path

TEMPLATE_PATH = Path("templates/mobile/add_order_customer_list.html")
BACKUP_PATH = TEMPLATE_PATH.with_suffix(".html.bak")

NEW_EXTRA_HEAD = """
<style>
    /* ---- Premium Customer Selection ---- */
    .back-link {
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        color: var(--text-secondary);
        text-decoration: none;
        font-size: 0.85rem;
        margin-bottom: 1rem;
        padding: 0.2rem 0;
        transition: color 0.2s;
    }
    .back-link:hover {
        color: var(--accent);
    }
    .back-link i {
        font-size: 0.9rem;
    }

    .page-title {
        font-size: 1.2rem;
        font-weight: 700;
        color: var(--text);
        margin-bottom: 0.3rem;
        display: flex;
        align-items: center;
        gap: 0.4rem;
    }
    .page-title i {
        color: var(--accent);
    }
    .page-sub {
        font-size: 0.85rem;
        color: var(--muted);
        margin-bottom: 1.2rem;
    }

    /* Search */
    .search-box {
        margin-bottom: 1.2rem;
    }
    .search-box .search-input-container {
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: 2.5rem;
        padding: 0.1rem 1rem;
        display: flex;
        align-items: center;
        transition: border-color 0.2s, box-shadow 0.2s;
        box-shadow: var(--shadow);
    }
    .search-box .search-input-container:focus-within {
        border-color: var(--accent);
        box-shadow: 0 0 0 3px rgba(230, 126, 34, 0.12);
    }
    .search-box .search-input-container i {
        color: var(--muted);
        margin-right: 0.5rem;
        font-size: 1rem;
    }
    .search-box .search-input-container input {
        border: none;
        background: transparent;
        padding: 0.7rem 0.2rem;
        font-size: 0.95rem;
        width: 100%;
        outline: none;
        color: var(--text);
    }
    .search-box .search-input-container input::placeholder {
        color: var(--muted);
        font-weight: 400;
    }

    /* Customer Cards */
    .customer-card {
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        padding: 0.9rem 1rem;
        margin-bottom: 0.7rem;
        display: flex;
        justify-content: space-between;
        align-items: center;
        box-shadow: var(--shadow);
        text-decoration: none;
        color: var(--text);
        transition: all 0.2s ease;
        position: relative;
        overflow: hidden;
    }
    .customer-card::after {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        width: 4px;
        height: 100%;
        background: var(--accent);
        opacity: 0;
        transition: opacity 0.2s;
    }
    .customer-card:active {
        transform: scale(0.98);
    }
    .customer-card:hover {
        border-color: var(--accent);
        box-shadow: 0 6px 20px rgba(0,0,0,0.06);
    }
    .customer-card:hover::after {
        opacity: 1;
    }
    .customer-info {
        flex: 1;
        min-width: 0;
    }
    .customer-info .name {
        font-weight: 700;
        font-size: 1.05rem;
        color: var(--text);
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 0.3rem 0.6rem;
    }
    .customer-info .phone {
        font-size: 0.8rem;
        color: var(--text-secondary);
        display: flex;
        align-items: center;
        gap: 0.3rem;
        margin-top: 0.1rem;
    }
    .customer-info .phone i {
        color: var(--muted);
        width: 1rem;
        font-size: 0.7rem;
    }
    .customer-info .address {
        font-size: 0.75rem;
        color: var(--muted);
        display: flex;
        align-items: center;
        gap: 0.3rem;
        margin-top: 0.1rem;
    }
    .customer-info .address i {
        color: var(--muted);
        width: 1rem;
        font-size: 0.7rem;
    }

    .badge-custom {
        display: inline-block;
        padding: 0.15rem 0.7rem;
        border-radius: 30px;
        font-weight: 700;
        font-size: 0.7rem;
        white-space: nowrap;
        background: var(--accent-light);
        color: var(--accent);
        border: 1px solid var(--accent);
    }
    .badge-pending {
        background: #fef3e2;
        color: #d35400;
        border-color: #f5cba7;
    }
    .badge-none {
        background: #e8f8f0;
        color: #1e7e34;
        border-color: #a3d9a5;
    }

    .card-arrow {
        color: var(--muted);
        font-size: 1.1rem;
        transition: transform 0.2s, color 0.2s;
        flex-shrink: 0;
        margin-left: 0.5rem;
    }
    .customer-card:hover .card-arrow {
        transform: translateX(4px);
        color: var(--accent);
    }

    /* Empty State */
    .empty-state {
        text-align: center;
        padding: 2.5rem 1rem;
        color: var(--muted);
        background: var(--surface);
        border-radius: var(--radius);
        border: 1px solid var(--border);
        box-shadow: var(--shadow);
    }
    .empty-state i {
        font-size: 2.8rem;
        color: var(--border);
        display: block;
        margin-bottom: 0.5rem;
    }
    .empty-state p {
        font-size: 0.95rem;
        margin: 0;
    }
    .empty-state .btn-create {
        display: inline-block;
        margin-top: 1rem;
        padding: 0.4rem 1.4rem;
        background: var(--accent);
        color: #fff;
        border-radius: 2rem;
        font-weight: 600;
        font-size: 0.85rem;
        text-decoration: none;
        transition: background 0.2s, transform 0.2s;
        box-shadow: 0 4px 12px rgba(230, 126, 34, 0.25);
    }
    .empty-state .btn-create:active {
        transform: scale(0.96);
    }
    .empty-state .btn-create:hover {
        background: var(--accent-hover);
    }

    @media (max-width: 400px) {
        .customer-card {
            padding: 0.7rem 0.8rem;
        }
        .customer-info .name {
            font-size: 0.95rem;
        }
        .badge-custom {
            font-size: 0.6rem;
            padding: 0.1rem 0.5rem;
        }
        .search-box .search-input-container input {
            font-size: 0.85rem;
        }
    }
</style>
"""

NEW_BODY = """
<a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="back-link">
    <i class="fas fa-arrow-left"></i> Back
</a>

<div class="page-title">
    <i class="fas fa-user-check"></i> Select Regular Customer
</div>
<div class="page-sub">Choose a customer to create a new order</div>

<div class="search-box">
    <form method="get" class="search-input-container">
        <i class="fas fa-search"></i>
        <input type="search" name="q" placeholder="Search by name or phone..." value="{{ request.GET.q|default:'' }}">
    </form>
</div>

{% for customer in customers %}
<a href="/portal/{{ tenant.schema_name }}/chakki/order/add/?customer_id={{ customer.id }}" class="customer-card">
    <div class="customer-info">
        <div class="name">
            {{ customer.name }}
            {% if customer.total_pending > 0 %}
                <span class="badge-custom badge-pending">₹{{ customer.total_pending|floatformat:2 }}</span>
            {% else %}
                <span class="badge-custom badge-none">✓ No due</span>
            {% endif %}
        </div>
        <div class="phone">
            <i class="fas fa-phone"></i> {{ customer.phone|default:"No phone" }}
        </div>
        <div class="address">
            <i class="fas fa-map-pin"></i> {{ customer.address|default:"No address" }}
        </div>
    </div>
    <i class="fas fa-chevron-right card-arrow"></i>
</a>
{% empty %}
<div class="empty-state">
    <i class="fas fa-users-slash"></i>
    <p>No customers found.</p>
    <a href="/portal/{{ tenant.schema_name }}/chakki/customer/create/" class="btn-create">
        <i class="fas fa-user-plus"></i> Create Customer
    </a>
</div>
{% endfor %}
"""

def replace_block(content, block_name, new_content):
    start_tag = f"{{% block {block_name} %}}"
    end_tag = "{% endblock %}"
    start_idx = content.find(start_tag)
    if start_idx == -1:
        print(f"⚠️ Block '{block_name}' not found. Appending at end.")
        body_end = content.rfind("</body>")
        if body_end != -1:
            return content[:body_end] + "\n" + new_content + "\n" + content[body_end:]
        else:
            return content + "\n" + new_content

    # Find matching endblock
    import re
    pattern = re.compile(r"({% block \w+ %})|({% endblock %})")
    matches = list(pattern.finditer(content, start_idx))
    depth = 0
    end_idx = None
    for match in matches:
        if match.group(1):
            depth += 1
        elif match.group(2):
            depth -= 1
            if depth == 0:
                end_idx = match.end()
                break
    if end_idx is None:
        print(f"⚠️ Could not find endblock for '{block_name}'. Skipping.")
        return content

    new_block = f"{start_tag}\n{new_content.strip()}\n{end_tag}"
    return content[:start_idx] + new_block + content[end_idx:]

def patch_file():
    if not TEMPLATE_PATH.exists():
        print(f"❌ File not found: {TEMPLATE_PATH}")
        return

    if not BACKUP_PATH.exists():
        TEMPLATE_PATH.rename(BACKUP_PATH)
        print(f"📁 Backup saved to {BACKUP_PATH}")
        content = BACKUP_PATH.read_text(encoding='utf-8')
    else:
        content = BACKUP_PATH.read_text(encoding='utf-8')
        print("ℹ️ Using existing backup.")

    content = replace_block(content, "extra_head", NEW_EXTRA_HEAD.strip())
    content = replace_block(content, "body", NEW_BODY.strip())

    TEMPLATE_PATH.write_text(content, encoding='utf-8')
    print(f"✅ Patched successfully! Updated {TEMPLATE_PATH}")

if __name__ == "__main__":
    patch_file()
