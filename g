#!/usr/bin/env python3
"""
Patcher to format large numbers with K, M, B suffixes in Revenue Analytics KPI cards.
Full number appears on hover (title attribute).
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
DESKTOP_TEMPLATE = PROJECT_ROOT / "reports" / "templates" / "desktop" / "reports_revenue.html"
MOBILE_TEMPLATE = PROJECT_ROOT / "reports" / "templates" / "mobile" / "reports_revenue.html"


def backup_file(path):
    if path.exists():
        backup_path = path.with_suffix(path.suffix + ".bak3")
        backup_path.write_bytes(path.read_bytes())
        print(f"📁 Backup created: {backup_path}")


def patch_template(template_path, is_mobile=False):
    if not template_path.exists():
        print(f"❌ Template not found: {template_path}")
        return False

    backup_file(template_path)
    content = template_path.read_text(encoding="utf-8")

    # 1. Insert the formatting script and styles into the extra_head block.
    # We'll add a style block and a script block.
    formatting_code = """
<style>
  .formatted-number {
    cursor: default;
  }
</style>
<script>
  document.addEventListener('DOMContentLoaded', function() {
    function formatNumber(num) {
      if (num >= 1e9) return (num / 1e9).toFixed(1) + 'B';
      if (num >= 1e6) return (num / 1e6).toFixed(1) + 'M';
      if (num >= 1e3) return (num / 1e3).toFixed(1) + 'K';
      return num.toString();
    }
    document.querySelectorAll('.kpi-card .number').forEach(el => {
      const rawText = el.textContent.trim();
      // Remove ₹ and commas, get numeric value
      const rawNum = parseFloat(rawText.replace(/[₹,]/g, ''));
      if (!isNaN(rawNum)) {
        const formatted = formatNumber(rawNum);
        // Keep the ₹ symbol if present
        const hasCurrency = rawText.includes('₹');
        el.innerHTML = (hasCurrency ? '₹' : '') + formatted;
        el.title = (hasCurrency ? '₹' : '') + rawNum.toFixed(2);
        // Ensure number is visible on hover
        el.style.cursor = 'default';
      }
    });
  });
</script>
"""
    # Find extra_head block and insert before its closing endblock
    extra_head_start = content.find("{% block extra_head %}")
    if extra_head_start != -1:
        extra_head_end = content.find("{% endblock %}", extra_head_start)
        if extra_head_end != -1:
            content = content[:extra_head_end] + formatting_code + "\n" + content[extra_head_end:]
        else:
            # If not found, insert after extra_head
            content = content.replace("{% block extra_head %}", "{% block extra_head %}\n" + formatting_code)
    else:
        # No extra_head, insert before closing head or at the end
        head_end = content.find("</head>")
        if head_end != -1:
            content = content[:head_end] + formatting_code + "\n" + content[head_end:]
        else:
            # Fallback: insert at the top of content block
            content = content.replace("{% block content %}", formatting_code + "{% block content %}")

    template_path.write_text(content, encoding="utf-8")
    print(f"✅ Updated {template_path.name}")
    return True


def main():
    print("🔧 Applying number formatting (K/M/B) to Revenue Analytics KPIs...")
    success = True
    success &= patch_template(DESKTOP_TEMPLATE, is_mobile=False)
    success &= patch_template(MOBILE_TEMPLATE, is_mobile=True)
    if success:
        print("\n✅ Formatting applied successfully!")
        print("👉 Restart your server and refresh the Revenue Analytics page.")
        print("   Large numbers will show with K/M/B suffixes; hover for full value.")
    else:
        print("\n❌ Some files were not patched.")


if __name__ == "__main__":
    main()
