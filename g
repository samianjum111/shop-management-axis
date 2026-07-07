#!/usr/bin/env python3
"""
Add a global "New Order" button to all pages (desktop & mobile).
- Desktop: placed in the header (right side).
- Mobile: floating action button above bottom nav.
Backups are created automatically.
"""

import os
import re

# ------------------------------------------------------------------------------
# Helper to inject HTML at a specific location
# ------------------------------------------------------------------------------
def inject_before(content, marker, new_html):
    """Insert new_html before the first occurrence of marker."""
    if marker not in content:
        return content
    return content.replace(marker, new_html + marker, 1)

def inject_after(content, marker, new_html):
    """Insert new_html after the first occurrence of marker."""
    if marker not in content:
        return content
    return content.replace(marker, marker + new_html, 1)

# ------------------------------------------------------------------------------
# Desktop base.html patch
# ------------------------------------------------------------------------------
def patch_desktop_base():
    path = "templates/desktop/base.html"
    if not os.path.exists(path):
        print(f"❌ {path} not found. Skipping desktop.")
        return

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if already patched
    if 'id="global-new-order-btn"' in content:
        print("✅ Desktop base already patched.")
        return

    # 1. Add CSS (inside <style> block)
    css_block = '''
        /* Global New Order Button */
        .global-new-order-btn {
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
            background: var(--accent);
            color: #fff !important;
            border: none;
            border-radius: 30px;
            padding: 0.4rem 1.2rem;
            font-weight: 600;
            font-size: 0.9rem;
            text-decoration: none;
            transition: background 0.2s, transform 0.15s;
            margin-left: 0.8rem;
        }
        .global-new-order-btn:hover {
            background: var(--accent-hover);
            color: #fff !important;
        }
        .global-new-order-btn:active {
            transform: scale(0.95);
        }
        .global-new-order-btn i {
            font-size: 0.9rem;
        }
        @media (max-width: 768px) {
            .global-new-order-btn {
                padding: 0.3rem 0.8rem;
                font-size: 0.8rem;
            }
        }
    '''
    # Insert before the closing </style>
    content = inject_before(content, '</style>', css_block)

    # 2. Add button inside .header .actions (after notifications)
    # Find the notifications div and insert after it.
    button_html = '''
            <a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="global-new-order-btn" id="global-new-order-btn">
                <i class="fas fa-plus-circle"></i> New Order
            </a>
    '''
    # We'll locate the notifications div and insert after it.
    # Look for: <div class="notifications dropdown"> ... </div>
    # We'll insert after that whole div.
    import re
    pattern = r'(<div class="notifications dropdown">.*?</div>)'
    match = re.search(pattern, content, flags=re.DOTALL)
    if match:
        notifications_div = match.group(0)
        new_content = content.replace(notifications_div, notifications_div + button_html, 1)
    else:
        # Fallback: insert at the end of .actions
        new_content = content.replace('</div>', button_html + '</div>', 1)  # approximate

    # Write backup
    with open(path + ".bak", 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"📦 Desktop backup saved to {path}.bak")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"✅ Patched {path}")

# ------------------------------------------------------------------------------
# Mobile base.html patch
# ------------------------------------------------------------------------------
def patch_mobile_base():
    path = "templates/mobile/base.html"
    if not os.path.exists(path):
        print(f"❌ {path} not found. Skipping mobile.")
        return

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'id="mobile-fab-btn"' in content:
        print("✅ Mobile base already patched.")
        return

    # 1. Add CSS for FAB
    css_block = '''
        /* Floating Action Button (New Order) */
        .fab-new-order {
            position: fixed;
            bottom: calc(72px + env(safe-area-inset-bottom, 0px) + 0.5rem);
            right: 1.2rem;
            z-index: 999;
            background: var(--accent);
            color: #fff;
            border: none;
            border-radius: 50%;
            width: 56px;
            height: 56px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.8rem;
            box-shadow: 0 4px 16px rgba(230,126,34,0.4);
            transition: transform 0.2s, box-shadow 0.2s;
            text-decoration: none;
        }
        .fab-new-order:active {
            transform: scale(0.90);
            box-shadow: 0 2px 8px rgba(230,126,34,0.3);
        }
        .fab-new-order i {
            color: #fff;
        }
        /* Small screen adjustment */
        @media (max-width: 400px) {
            .fab-new-order {
                width: 48px;
                height: 48px;
                font-size: 1.4rem;
                right: 0.8rem;
                bottom: calc(68px + env(safe-area-inset-bottom, 0px) + 0.5rem);
            }
        }
    '''
    content = inject_before(content, '</style>', css_block)

    # 2. Add the button HTML just before the closing </body>
    fab_html = '''
    <!-- Floating New Order Button -->
    <a href="/portal/{{ tenant.schema_name }}/chakki/add/" class="fab-new-order" id="mobile-fab-btn">
        <i class="fas fa-plus"></i>
    </a>
    '''
    content = inject_before(content, '</body>', fab_html)

    # Write backup
    with open(path + ".bak", 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"📦 Mobile backup saved to {path}.bak")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Patched {path}")

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
def main():
    print("🚀 Adding global 'New Order' button...")
    patch_desktop_base()
    patch_mobile_base()
    print("\n🎉 All done! Restart your server to see the new button everywhere.")

if __name__ == "__main__":
    main()
