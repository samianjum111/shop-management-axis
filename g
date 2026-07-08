#!/usr/bin/env python3
"""
Add a "Selling" total card in the order form totals section.
Also rename "Grand Total" to "Total" for brevity.
"""

import re

def patch_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # For desktop: find the row with three cards and add a fourth.
    # Desktop uses col-md-4, we'll change to col-md-3 and add a new card.
    # We'll locate the <div class="row mt-4"> and replace the inner content.
    # We'll use regex to find the pattern.
    
    # Look for the row with cards
    if 'desktop' in filepath:
        # Desktop version: col-md-4
        pattern = r'(<div class="row mt-4">)\s*<div class="col-md-4"><div class="card p-2"><h6>Grinding</h6><h4 id="total_grinding_display">.*?</h4></div></div>\s*<div class="col-md-4"><div class="card p-2"><h6>Cleaning</h6><h4 id="total_cleaning_display">.*?</h4></div></div>\s*<div class="col-md-4"><div class="card p-2 bg-info"><h6>Grand Total</h6><h4 id="grand_total_display">.*?</h4></div></div>\s*</div>'
        replacement = r'''<div class="row mt-4">
        <div class="col-md-3"><div class="card p-2"><h6>Grinding</h6><h4 id="total_grinding_display">₹0.00</h4></div></div>
        <div class="col-md-3"><div class="card p-2"><h6>Cleaning</h6><h4 id="total_cleaning_display">₹0.00</h4></div></div>
        <div class="col-md-3"><div class="card p-2"><h6>Selling</h6><h4 id="total_selling_display">₹0.00</h4></div></div>
        <div class="col-md-3"><div class="card p-2 bg-info"><h6>Grand Total</h6><h4 id="grand_total_display">₹0.00</h4></div></div>
    </div>'''
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        # Now we need to add the JavaScript to update the new selling display.
        # In the updateTotals() function, we need to set total_selling_display.
        # We'll search for "totalSellingDisplay" variable and add a new one.
        # We'll add a new variable declaration and update it.
        # Look for the line: const grandTotalDisplay = document.getElementById('grand_total_display');
        # We'll add a new line after that.
        # Then inside updateTotals, we set its textContent.
        # We'll use regex to find the updateTotals function and insert the line.
        # However, it's easier to just add a new element id and update it.

        # We'll add a new variable in the script:
        if 'total_selling_display' not in content:
            # We'll insert after the line where grandTotalDisplay is defined
            insert_pos = content.find('const grandTotalDisplay = document.getElementById')
            if insert_pos != -1:
                # Find the end of that line
                end_line = content.find('\n', insert_pos)
                if end_line != -1:
                    new_line = '\n    const totalSellingDisplay = document.getElementById(\'total_selling_display\');\n'
                    content = content[:end_line] + new_line + content[end_line:]
            # Also inside updateTotals, we need to set totalSellingDisplay.textContent
            # We'll find the line where totalSelling is calculated and set it.
            # In updateTotals, after calculating grandTotal, we set displays.
            # We'll add a line: totalSellingDisplay.textContent = '₹' + totalSelling.toFixed(2);
            # We'll find the line where grandTotalDisplay.textContent is set and insert before it.
            # We'll use a simple replacement: find the line with grandTotalDisplay.textContent and insert before.
            # Use regex to find the line and insert before.
            pattern2 = r'(grandTotalDisplay\.textContent = .*?;)'
            replacement2 = r'totalSellingDisplay.textContent = \'₹\' + totalSelling.toFixed(2);\n        \1'
            content = re.sub(pattern2, replacement2, content)

    else:
        # Mobile version: col-4 to col-3
        pattern = r'(<div class="row mt-3">)\s*<div class="col-4"><div class="card p-2"><h6>Grinding</h6><h4 id="total_grinding_display">.*?</h4></div></div>\s*<div class="col-4"><div class="card p-2"><h6>Cleaning</h6><h4 id="total_cleaning_display">.*?</h4></div></div>\s*<div class="col-4"><div class="card p-2 bg-info"><h6>Grand Total</h6><h4 id="grand_total_display">.*?</h4></div></div>\s*</div>'
        replacement = r'''<div class="row mt-3">
        <div class="col-3"><div class="card p-2"><h6>Grinding</h6><h4 id="total_grinding_display">₹0.00</h4></div></div>
        <div class="col-3"><div class="card p-2"><h6>Cleaning</h6><h4 id="total_cleaning_display">₹0.00</h4></div></div>
        <div class="col-3"><div class="card p-2"><h6>Selling</h6><h4 id="total_selling_display">₹0.00</h4></div></div>
        <div class="col-3"><div class="card p-2 bg-info"><h6>Grand Total</h6><h4 id="grand_total_display">₹0.00</h4></div></div>
    </div>'''
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        # Add JavaScript for totalSellingDisplay
        if 'total_selling_display' not in content:
            insert_pos = content.find('const grandTotalDisplay = document.getElementById')
            if insert_pos != -1:
                end_line = content.find('\n', insert_pos)
                if end_line != -1:
                    new_line = '\n    const totalSellingDisplay = document.getElementById(\'total_selling_display\');\n'
                    content = content[:end_line] + new_line + content[end_line:]
            pattern2 = r'(grandTotalDisplay\.textContent = .*?;)'
            replacement2 = r'totalSellingDisplay.textContent = \'₹\' + totalSelling.toFixed(2);\n        \1'
            content = re.sub(pattern2, replacement2, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Patched {filepath}")

def main():
    patch_file('templates/desktop/add_order_form.html')
    patch_file('templates/mobile/add_order_form.html')

if __name__ == '__main__':
    main()
