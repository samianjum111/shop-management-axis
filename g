#!/usr/bin/env python3
"""
Remove the "Go to Login" button from root_home.html.
The page will still show the welcome message and portal URL example.
"""

from pathlib import Path

TEMPLATE_PATH = Path(__file__).parent / 'templates' / 'root_home.html'

def remove_button():
    if not TEMPLATE_PATH.exists():
        print(f"❌ {TEMPLATE_PATH} not found.")
        return False

    with open(TEMPLATE_PATH, 'r') as f:
        content = f.read()

    # Remove the anchor tag containing "Go to Login"
    # We'll replace the line(s) that contain the button.
    # The button is: <a href="/login/" class="portal-link">Go to Login</a>
    # We'll remove that entire line, but keep any surrounding content.
    lines = content.splitlines()
    new_lines = []
    for line in lines:
        if 'Go to Login' in line and 'portal-link' in line:
            # Skip this line entirely (remove the button)
            continue
        new_lines.append(line)

    new_content = '\n'.join(new_lines)

    # If nothing changed, print a warning but still save (idempotent)
    if new_content == content:
        print("⚠️  Button not found or already removed.")
    else:
        with open(TEMPLATE_PATH, 'w') as f:
            f.write(new_content)
        print("✅ Removed 'Go to Login' button from root_home.html.")

    return True

def main():
    print("🚀 Removing login button from root_home.html...")
    if remove_button():
        print("\n✅ Done. Restart your server to see the change.")

if __name__ == "__main__":
    main()
