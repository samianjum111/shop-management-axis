#!/usr/bin/env python3
"""
Professional PWA Patcher – Single‑click setup for Chakki SaaS.
Removes clutter, adds a clean install button with fallback, and ensures
the app opens the tenant dashboard after installation.
"""

import os
import json
import shutil
import subprocess

# ---------- PATHS ----------
BASE_DIR = "/var/www/shop-management-axis"
STATIC_DIR = os.path.join(BASE_DIR, "static")
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

MOBILE_BASE = os.path.join(TEMPLATES_DIR, "mobile", "base.html")
DESKTOP_BASE = os.path.join(TEMPLATES_DIR, "desktop", "base.html")
ROOT_HTML = os.path.join(TEMPLATES_DIR, "root.html")
MANIFEST_PATH = os.path.join(STATIC_DIR, "manifest.json")
SW_PATH = os.path.join(STATIC_DIR, "sw.js")

# ---------- NEW FILE CONTENTS ----------

NEW_MANIFEST = {
    "name": "Chakki SaaS",
    "short_name": "Chakki",
    "start_url": "/",
    "scope": "/",
    "display": "standalone",
    "theme_color": "#1a2a3a",
    "background_color": "#f0f2f5",
    "icons": [
        {"src": "/static/icon-192x192.png", "sizes": "192x192", "type": "image/png"},
        {"src": "/static/icon-512x512.png", "sizes": "512x512", "type": "image/png"}
    ],
    "apple-touch-icon": "/static/apple-touch-icon.png"
}

NEW_SW = '''// Service Worker – Chakki SaaS
const CACHE_NAME = 'chakki-v2';
const urlsToCache = [
  '/',
  '/static/manifest.json'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('[SW] Cache opened');
        return cache.addAll(urlsToCache);
      })
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        if (response) return response;
        return fetch(event.request).then(fetchRes => {
          if (fetchRes && fetchRes.status === 200) {
            const clone = fetchRes.clone();
            caches.open(CACHE_NAME).then(cache => {
              cache.put(event.request, clone);
            });
          }
          return fetchRes;
        });
      })
  );
});

self.addEventListener('activate', event => {
  const whitelist = [CACHE_NAME];
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(name => {
          if (!whitelist.includes(name)) return caches.delete(name);
        })
      );
    })
  );
});
'''

# The PWA install block – clean, professional, with fallback
PWA_INSTALL_BLOCK = '''
<!-- ===== PWA INSTALL (Professional) ===== -->
<style>
  .pwa-install-wrapper {
    position: fixed;
    bottom: calc(80px + env(safe-area-inset-bottom, 0px));
    right: 16px;
    z-index: 9999;
    display: none; /* hidden by default, shown by JS when needed */
    flex-direction: column;
    align-items: flex-end;
    gap: 6px;
  }
  .pwa-install-wrapper .pwa-btn {
    background: #1a2a3a;
    color: #fff;
    border: none;
    border-radius: 50px;
    padding: 10px 20px;
    font-size: 14px;
    font-weight: 600;
    box-shadow: 0 6px 24px rgba(0,0,0,0.25);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    transition: transform 0.15s, box-shadow 0.15s;
    backdrop-filter: blur(4px);
    border: 1px solid rgba(255,255,255,0.1);
  }
  .pwa-install-wrapper .pwa-btn i {
    font-size: 18px;
  }
  .pwa-install-wrapper .pwa-btn:active {
    transform: scale(0.94);
  }
  .pwa-install-wrapper .pwa-btn:hover {
    box-shadow: 0 8px 32px rgba(0,0,0,0.35);
  }
  .pwa-install-wrapper .pwa-close {
    background: rgba(0,0,0,0.4);
    color: #fff;
    border: none;
    border-radius: 50%;
    width: 28px;
    height: 28px;
    font-size: 14px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    backdrop-filter: blur(4px);
    transition: background 0.2s;
  }
  .pwa-install-wrapper .pwa-close:hover {
    background: rgba(0,0,0,0.6);
  }
  @media (max-width: 400px) {
    .pwa-install-wrapper .pwa-btn {
      padding: 8px 14px;
      font-size: 12px;
    }
    .pwa-install-wrapper .pwa-btn i {
      font-size: 16px;
    }
  }
  /* Modal overlay for fallback instructions */
  .pwa-modal-overlay {
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.5);
    backdrop-filter: blur(6px);
    z-index: 10000;
    display: none;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  .pwa-modal-overlay.active {
    display: flex;
  }
  .pwa-modal-box {
    background: #fff;
    border-radius: 24px;
    max-width: 380px;
    width: 100%;
    padding: 28px 24px 20px;
    box-shadow: 0 24px 64px rgba(0,0,0,0.3);
    color: #1a1a2e;
    position: relative;
  }
  .pwa-modal-box h3 {
    margin: 0 0 4px;
    font-size: 1.3rem;
    font-weight: 700;
  }
  .pwa-modal-box p {
    font-size: 0.95rem;
    color: #4a5568;
    margin: 6px 0 16px;
    line-height: 1.5;
  }
  .pwa-modal-box .step {
    display: flex;
    align-items: center;
    gap: 10px;
    margin: 10px 0;
    font-size: 0.9rem;
  }
  .pwa-modal-box .step .num {
    background: #e2e8f0;
    border-radius: 50%;
    width: 28px;
    height: 28px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    color: #2d3748;
    flex-shrink: 0;
  }
  .pwa-modal-box .btn-close-modal {
    background: #1a2a3a;
    color: #fff;
    border: none;
    border-radius: 40px;
    padding: 10px 0;
    width: 100%;
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
    margin-top: 12px;
    transition: background 0.2s;
  }
  .pwa-modal-box .btn-close-modal:hover {
    background: #2c3e50;
  }
</style>

<div class="pwa-install-wrapper" id="pwaInstallWrapper">
  <button class="pwa-btn" id="pwaInstallBtn">
    <i class="fas fa-download"></i> Install App
  </button>
  <button class="pwa-close" id="pwaCloseBtn" title="Dismiss">✕</button>
</div>

<!-- Fallback Modal -->
<div class="pwa-modal-overlay" id="pwaModalOverlay">
  <div class="pwa-modal-box">
    <h3>📲 Install this app</h3>
    <p>Add this app to your home screen for quick access.</p>
    <div class="step"><span class="num">1</span> Tap the share icon <i class="fas fa-share-alt" style="color:#2563eb;"></i> in your browser</div>
    <div class="step"><span class="num">2</span> Select <strong>“Add to Home Screen”</strong></div>
    <div class="step"><span class="num">3</span> Tap <strong>“Add”</strong> – done!</div>
    <button class="btn-close-modal" id="pwaModalClose">Got it</button>
  </div>
</div>

<script>
(function() {
  // ----- Variables -----
  let deferredPrompt = null;
  const wrapper = document.getElementById('pwaInstallWrapper');
  const installBtn = document.getElementById('pwaInstallBtn');
  const closeBtn = document.getElementById('pwaCloseBtn');
  const modalOverlay = document.getElementById('pwaModalOverlay');
  const modalClose = document.getElementById('pwaModalClose');

  // ----- Check if already installed (standalone mode) -----
  function isInstalled() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           window.navigator.standalone === true;  // iOS
  }

  // ----- Show / hide the install button -----
  function updateInstallButton() {
    if (isInstalled()) {
      wrapper.style.display = 'none';
      return;
    }
    // If the app is not installed, show the button.
    // On HTTP we won't have deferredPrompt, but we show it anyway.
    wrapper.style.display = 'flex';
  }

  // ----- Native install prompt (only on HTTPS) -----
  window.addEventListener('beforeinstallprompt', function(e) {
    e.preventDefault();
    deferredPrompt = e;
    // We already show the button; no extra action needed.
    console.log('[PWA] beforeinstallprompt captured');
  });

  // ----- Install button click -----
  installBtn.addEventListener('click', function() {
    if (deferredPrompt) {
      // Native prompt available (HTTPS)
      deferredPrompt.prompt();
      deferredPrompt.userChoice.then(function(choice) {
        if (choice.outcome === 'accepted') {
          console.log('[PWA] User accepted install');
          wrapper.style.display = 'none';
        } else {
          console.log('[PWA] User dismissed install');
        }
        deferredPrompt = null;
      });
    } else {
      // No native prompt → show fallback modal with instructions
      modalOverlay.classList.add('active');
    }
  });

  // ----- Close button (dismiss the install button) -----
  closeBtn.addEventListener('click', function() {
    wrapper.style.display = 'none';
    // Remember that the user dismissed it (optional)
    try {
      localStorage.setItem('pwa_dismissed', 'true');
    } catch(e) {}
  });

  // ----- Modal close -----
  function closeModal() {
    modalOverlay.classList.remove('active');
  }
  modalClose.addEventListener('click', closeModal);
  modalOverlay.addEventListener('click', function(e) {
    if (e.target === modalOverlay) closeModal();
  });

  // ----- Also hide if user previously dismissed -----
  try {
    if (localStorage.getItem('pwa_dismissed') === 'true') {
      wrapper.style.display = 'none';
    }
  } catch(e) {}

  // ----- Service Worker registration (already in base) -----
  // (We keep the existing registration code)
  // But we ensure it's registered.
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/static/sw.js', { scope: '/' })
      .then(function(reg) {
        console.log('[SW] Registered');
      })
      .catch(function(err) {
        console.log('[SW] Registration failed: ', err);
      });
  }

  // ----- Store tenant in localStorage (for root redirect) -----
  const path = window.location.pathname;
  const match = path.match(/^\\/portal\\/([^\\/]+)/);
  if (match) {
    localStorage.setItem('chakki_tenant', match[1]);
  }

  // ----- Initial state -----
  updateInstallButton();

  // Re-check when the user returns to the app (e.g., after install)
  window.addEventListener('pageshow', function() {
    updateInstallButton();
  });

  // Also listen for appinstalled event (not widely supported)
  window.addEventListener('appinstalled', function() {
    wrapper.style.display = 'none';
    try { localStorage.removeItem('pwa_dismissed'); } catch(e) {}
  });

})();
</script>
<!-- ===== END PWA INSTALL ===== -->
'''

# The root.html – redirects to tenant dashboard
NEW_ROOT_HTML = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Chakki Portal</title>
    <link rel="manifest" href="/static/manifest.json">
    <meta name="theme-color" content="#1a2a3a">
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
            border-radius: 1.2rem;
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
            border-top: 4px solid #1a2a3a;
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
            // Get tenant from localStorage (set on login or saved)
            let tenant = localStorage.getItem('chakki_tenant');
            // If not set, try to extract from URL (for direct access)
            if (!tenant) {
                const path = window.location.pathname;
                const match = path.match(/^\\/portal\\/([^\\/]+)/);
                if (match) {
                    tenant = match[1];
                    localStorage.setItem('chakki_tenant', tenant);
                }
            }
            // Fallback to default tenant (change '2' if needed)
            if (!tenant) {
                tenant = '2';
                localStorage.setItem('chakki_tenant', tenant);
            }
            // Redirect to tenant dashboard
            window.location.href = '/portal/' + tenant + '/dashboard/';
        })();
    </script>
</body>
</html>
'''

# ---------- HELPER FUNCTIONS ----------

def backup_file(path):
    if os.path.exists(path):
        shutil.copy2(path, path + '.bak')
        print(f"📦 Backed up: {path}")

def write_file(path, content):
    with open(path, 'w') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

def patch_base_html(filepath):
    """Replace the entire PWA install block in base.html with our clean version."""
    if not os.path.exists(filepath):
        print(f"⚠️  File not found: {filepath}")
        return

    with open(filepath, 'r') as f:
        content = f.read()

    # Check if we already have our new block (avoid duplicate patching)
    if 'pwa-install-wrapper' in content and 'pwaModalOverlay' in content:
        print(f"⏩ {filepath} already has the new PWA block – skipping.")
        return

    # Backup
    backup_file(filepath)

    # Remove any old PWA blocks (search for known markers)
    import re
    # Remove old install button div (if any)
    content = re.sub(r'<div[^>]*id="pwa-install-btn"[^>]*>.*?</div>', '', content, flags=re.DOTALL)
    # Remove old script blocks that handle install (to avoid duplicates)
    content = re.sub(r'<script>.*?PWA install prompt.*?</script>', '', content, flags=re.DOTALL)

    # Insert our new block just before </body>
    if '</body>' in content:
        content = content.replace('</body>', PWA_INSTALL_BLOCK + '\n</body>')
    else:
        content += PWA_INSTALL_BLOCK

    write_file(filepath, content)

# ---------- MAIN ----------

def main():
    print("🔧 Starting Professional PWA Patcher...\n")

    # 1. Manifest
    print("📱 Updating manifest.json...")
    backup_file(MANIFEST_PATH)
    with open(MANIFEST_PATH, 'w') as f:
        json.dump(NEW_MANIFEST, f, indent=2)
    print("✅ manifest.json updated")

    # 2. Service Worker
    print("⚙️  Updating sw.js...")
    backup_file(SW_PATH)
    write_file(SW_PATH, NEW_SW)

    # 3. Root HTML
    print("🌐 Updating root.html...")
    backup_file(ROOT_HTML)
    write_file(ROOT_HTML, NEW_ROOT_HTML)

    # 4. Base templates (mobile & desktop)
    print("📄 Patching base templates...")
    patch_base_html(MOBILE_BASE)
    patch_base_html(DESKTOP_BASE)

    # 5. Restart Gunicorn
    print("🔄 Restarting Gunicorn...")
    subprocess.run(["sudo", "systemctl", "restart", "gunicorn"], check=False)

    print("\n🎉 PWA Patcher completed successfully!")
    print("📌 What changed:")
    print("  - manifest.json → correct start_url, scope, theme")
    print("  - sw.js → modern caching strategy")
    print("  - root.html → smart tenant redirect")
    print("  - base.html → clean install button with fallback modal")
    print("\n💡 The install button will appear in the bottom-right corner.")
    print("   - On HTTPS: it triggers the native install prompt.")
    print("   - On HTTP: it shows a helpful modal with manual install steps.")
    print("   - After installation, the app opens the tenant dashboard.\n")
    print("👉 Clear your browser cache and reload the page to see the changes.")

if __name__ == "__main__":
    main()
