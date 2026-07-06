#!/usr/bin/env python3
import re

def fix_views():
    file_path = 'expenses/views.py'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Ensure mark_safe is imported
    if 'from django.utils.safestring import mark_safe' not in content:
        # Insert after the existing imports (after the last 'from' or 'import')
        lines = content.splitlines()
        # Find the last import line
        import_lines = [i for i, line in enumerate(lines) if line.startswith('from ') or line.startswith('import ')]
        if import_lines:
            last_import = import_lines[-1]
            lines.insert(last_import + 1, 'from django.utils.safestring import mark_safe')
        else:
            # If no imports, add at top
            lines.insert(0, 'from django.utils.safestring import mark_safe')
        content = '\n'.join(lines)

    # 2. Replace the messages.error line with mark_safe
    pattern = r"(messages\.error\(request,\s*)(f\"A worker with CNIC '\{cnic\}' already exists\. <a href='/portal/\{request\.tenant\.schema_name\}/expenses/workers/\{existing_worker\.id\}/'>View Profile</a>\")(\))"
    replacement = r'\1mark_safe(\2)\3'
    new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("✅ Updated expenses/views.py: added mark_safe to duplicate CNIC message.")
    else:
        print("⚠️ No change made to expenses/views.py – pattern not found or already fixed.")

def fix_templates():
    templates = ['templates/mobile/base.html', 'templates/desktop/base.html']
    for template_path in templates:
        with open(template_path, 'r', encoding='utf-8') as f:
            content = f.read()
        # Replace {{ m }} with {{ m|safe }} in message display
        # Find the pattern: {{ m }} inside the message loop
        # We'll look for the line that displays the message.
        # Typically: <div class="message ...">{{ m }}</div>
        # We'll replace with {{ m|safe }}
        pattern = r'(<div class="message[^>]*>)\s*\{\{\s*m\s*\}\}\s*(</div>)'
        replacement = r'\1{{ m|safe }}\2'
        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        if new_content != content:
            with open(template_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"✅ Updated {template_path}: message tag now uses safe filter.")
        else:
            print(f"⚠️ No change to {template_path} – pattern not found or already fixed.")

if __name__ == '__main__':
    fix_views()
    fix_templates()
    print("\n🎉 All fixes applied. Restart your server to see the clickable link.")
