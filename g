#!/usr/bin/env python3
"""
Make the PWA root page tenant‑aware and service‑worker‑friendly.
- Replaces server‑side redirect with a client‑side JS redirect.
- Updates sw.js to cache only 200 responses.
- Adds a login hook to store tenant in localStorage.
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
TEMPLATES = PROJECT_ROOT / 'templates'
STATIC_DIR = PROJECT_ROOT / 'static'
SW = STATIC_DIR / 'sw.js'
CORE_VIEWS = PROJECT_ROOT / 'core' / 'views.py'
CORE_URLS = PROJECT_ROOT / 'core' / 'urls.py'
MOBILE_BASE = TEMPLATES / 'mobile' / 'base.html'
DESKTOP_BASE = TEMPLATES / 'desktop' / 'base.html'

# New root template – will be served at '/'
ROOT_HTML = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Chakki Portal</title>
    <link rel="manifest" href="/static/manifest.json">
    <meta name="theme-color" content="#343a40">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #f8f9fa;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
            text-align: center;
        }
        .loader {
            background: white;
            padding: 2rem;
            border-radius: 1rem;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            max-width: 400px;
        }
        .loader h1 {
            font-size: 1.5rem;
            color: #1a1a2e;
            margin-bottom: 0.5rem;
        }
        .loader .spinner {
            display: inline-block;
            width: 40px;
            height: 40px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #e67e22;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin: 1rem 0;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .loader .error {
            color: #dc3545;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="loader" id="loader">
        <h1>Chakki</h1>
        <p>Redirecting to your dashboard...</p>
        <div class="spinner"></div>
        <div id="error" class="error" style="display:none;"></div>
    </div>
    <script>
        (function() {
            // Get tenant from localStorage (set on login) or fallback
            let tenant = localStorage.getItem('chakki_tenant');
            if (!tenant) {
                // If not set, try to get from URL if any (for direct access)
                const path = window.location.pathname;
                const match = path.match(/^\\/portal\\/([^\\/]+)/);
                if (match) {
                    tenant = match[1];
                    localStorage.setItem('chakki_tenant', tenant);
                }
            }
            if (tenant) {
                // Redirect to tenant dashboard
                window.location.href = '/portal/' + tenant + '/dashboard/';
            } else {
                // Fallback to tenant '2' (adjust as needed)
                localStorage.setItem('chakki_tenant', '2');
                window.location.href = '/portal/2/dashboard/';
            }
        })();
    </script>
</body>
</html>
'''

def patch_file(filepath, search, replacement, flags=0):
    if not filepath.exists():
        print(f"❌ {filepath} not found")
        return False
    content = filepath.read_text(encoding='utf-8')
    if not re.search(search, content, flags):
        print(f"⚠️  Pattern not found in {filepath}, skipping.")
        return False
    new_content = re.sub(search, replacement, content, flags=flags)
    filepath.write_text(new_content, encoding='utf-8')
    print(f"✅ Patched {filepath}")
    return True

def main():
    # 1. Create root.html template
    root_template = TEMPLATES / 'root.html'
    root_template.write_text(ROOT_HTML, encoding='utf-8')
    print(f"✅ Created {root_template}")

    # 2. Update core/views.py: replace root_redirect with a template render
    view_content = CORE_VIEWS.read_text(encoding='utf-8')
    # Remove old root_redirect function if present
    old_func_pattern = r'def root_redirect\(.*?\).*?(?=\ndef |\Z)'
    if re.search(old_func_pattern, view_content, re.DOTALL):
        view_content = re.sub(old_func_pattern, '', view_content, flags=re.DOTALL)
    # Add new function
    new_func = '''
def root_redirect(request):
    """Serve a simple HTML page that redirects via JavaScript."""
    return render(request, 'root.html')
'''
    # Insert before the last line or at the end
    view_content = view_content.rstrip() + '\n\n' + new_func.strip() + '\n'
    CORE_VIEWS.write_text(view_content, encoding='utf-8')
    print("✅ Updated core/views.py with new root_redirect")

    # 3. Update sw.js to cache only 200 responses
    if SW.exists():
        sw_content = SW.read_text(encoding='utf-8')
        # Replace the fetch handler with one that checks status
        new_fetch = '''
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        if (response) {
          // Only return cached response if it's a 200 OK
          if (response.status === 200) {
            return response;
          }
        }
        return fetch(event.request).then(fetchResponse => {
          // Cache only successful responses
          if (fetchResponse && fetchResponse.status === 200) {
            const responseClone = fetchResponse.clone();
            caches.open(CACHE_NAME).then(cache => {
              cache.put(event.request, responseClone);
            });
          }
          return fetchResponse;
        });
      })
  );
});
'''
        # Find existing fetch handler and replace
        fetch_pattern = r'self\.addEventListener\(\'fetch\',.*?\);'
        sw_content = re.sub(fetch_pattern, new_fetch, sw_content, flags=re.DOTALL)
        SW.write_text(sw_content, encoding='utf-8')
        print("✅ Updated sw.js to cache only 200 OK responses")
    else:
        print("❌ sw.js not found")

    # 4. Add login hook to store tenant in localStorage
    # We'll inject a small script into base.html (both mobile and desktop)
    login_hook = '''
    <script>
    // Store tenant in localStorage for PWA root redirect
    (function() {
        const tenant = '{{ tenant.schema_name }}';
        if (tenant) {
            localStorage.setItem('chakki_tenant', tenant);
        }
    })();
    </script>
'''
    # Add after the PWA meta tags or before </head>? We'll add before </body>.
    for base in [MOBILE_BASE, DESKTOP_BASE]:
        if base.exists():
            content = base.read_text(encoding='utf-8')
            # Insert before </body>
            if '</body>' in content:
                content = content.replace('</body>', login_hook + '\n</body>')
                base.write_text(content, encoding='utf-8')
                print(f"✅ Added login hook to {base}")
            else:
                print(f"⚠️  No </body> in {base}, skipping")
        else:
            print(f"❌ {base} not found")

    print("\n📌 Next steps:")
    print("1. Run: python3 manage.py collectstatic --noinput")
    print("2. Restart your server")
    print("3. **Uninstall the current PWA** from your browser/device (clear site data if needed).")
    print("4. Visit your site again and re‑install the PWA.")
    print("5. The app should now open directly to your dashboard without errors.")
    print("6. If you have multiple tenants, ensure the user is logged in on at least one tenant.")
    print("   The tenant is stored in localStorage during login, so the root page knows where to go.")

if __name__ == '__main__':
    main()
