#!/usr/bin/env python3
"""
Fix PWA start_url and service worker cache.
Run from project root.
"""

import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
STATIC_DIR = PROJECT_ROOT / 'static'
MANIFEST = STATIC_DIR / 'manifest.json'
SW = STATIC_DIR / 'sw.js'

# Change this to a valid URL that returns 200
# For your setup, use your tenant dashboard, e.g., /portal/2/dashboard/
START_URL = '/portal/2/dashboard/'

def main():
    print(f"🔧 Setting PWA start_url to: {START_URL}")

    # 1. Update manifest
    if MANIFEST.exists():
        with open(MANIFEST, 'r') as f:
            manifest = json.load(f)
        manifest['start_url'] = START_URL
        with open(MANIFEST, 'w') as f:
            json.dump(manifest, f, indent=2)
        print("✅ Updated manifest.json")
    else:
        print("❌ manifest.json not found")

    # 2. Update service worker cache list
    if SW.exists():
        content = SW.read_text()
        # Replace the urlsToCache array – we'll keep only the new start_url
        # and manifest itself
        new_cache = f"const urlsToCache = [\n  '{START_URL}',\n  '/static/manifest.json',\n];"
        # Find the line with 'const urlsToCache' and replace it
        import re
        pattern = r'const urlsToCache = \[.*?\];'
        content = re.sub(pattern, new_cache, content, flags=re.DOTALL)
        SW.write_text(content)
        print("✅ Updated sw.js")
    else:
        print("❌ sw.js not found")

    print("\n📌 Next steps:")
    print("1. Run: python3 manage.py collectstatic --noinput")
    print("2. Restart your server")
    print("3. Open Chrome DevTools > Application > Manifest to verify no errors")
    print("4. If the install button still doesn't appear, try:")
    print("   - Open the three-dot menu in Chrome > 'Install App' (if available)")
    print("   - Or use the 'Add to Home Screen' option from the address bar")

if __name__ == '__main__':
    main()
