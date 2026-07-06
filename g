#!/usr/bin/env python3
import os
import re

BASE_DIR = os.getcwd()
MOBILE_DIR = os.path.join(BASE_DIR, "templates", "mobile")

def update_block_names():
    """Replace {% block content %} with {% block body %} in all mobile templates (except base.html)."""
    for filename in os.listdir(MOBILE_DIR):
        if not filename.endswith(".html"):
            continue
        if filename in ["base.html", "transcript.html"]:
            continue  # don't touch these

        filepath = os.path.join(MOBILE_DIR, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # Only process files that extend mobile/base.html
        if '{% extends "mobile/base.html" %}' not in content:
            print(f"⏭️ Skipping {filename} (does not extend base)")
            continue

        # Replace block content with block body
        if '{% block content %}' in content:
            content = content.replace('{% block content %}', '{% block body %}')
        if '{% endblock content %}' in content:
            content = content.replace('{% endblock content %}', '{% endblock %}')
        # Also handle generic {% endblock %} – already fine

        # Optional: remove duplicate search forms in order_list and search
        if filename in ["order_list.html", "search.html"]:
            # Remove the search form inside the page, because base already has a global search
            # We'll use regex to remove the form if it's present
            # Simple approach: remove the form block if it contains 'search' in the method
            # But to be safe, we'll just comment out or remove the form tag and its surrounding
            # We'll search for <form method="get" ...> and remove it
            # Since it's a simple removal, we'll do a crude replace
            # Remove the search form from order_list.html and search.html
            # The form usually is: <form method="get" class="mb-3"> ... </form>
            # We'll remove the entire form tag
            # But careful: there might be multiple forms, only remove the one with 'search' in input name
            # Actually we can just remove the entire search div that contains the input-group
            pattern = r'<form[^>]*method="get"[^>]*>.*?<input[^>]*name="search".*?</form>'
            content = re.sub(pattern, '', content, flags=re.DOTALL)
            # Also remove any leftover <div> wrappers
            content = re.sub(r'<div[^>]*class="input-group"[^>]*>.*?</div>', '', content, flags=re.DOTALL)

        # Write back
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Updated {filename}")

def main():
    print("🔧 Fixing mobile templates to use new base.html...")
    update_block_names()
    print("🎉 All done! Restart your server and check all mobile pages.")

if __name__ == "__main__":
    main()
