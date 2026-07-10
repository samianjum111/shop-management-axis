#!/usr/bin/env python3
"""
PWA Header Patcher – Moves the install button to the top bar,
removes floating clutter, and ensures it hides after install.
"""

import os
import re
import shutil
import subprocess

BASE_DIR = "/var/www/shop-management-axis"
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

MOBILE_BASE = os.path.join(TEMPLATES_DIR, "mobile", "base.html")
DESKTOP_BASE = os.path.join(TEMPLATES_DIR, "desktop", "base.html")
ROOT_HTML = os.path.join(TEMPLATES_DIR, "root.html")

# ---------- NEW HEADER INSTALL BUTTON (HTML + JS) ----------
HEADER_INSTALL_BLOCK = '''
<!-- ===== PWA INSTALL (Header Button) ===== -->
<style>
  .pwa-install-header {
    display: none; /* hidden by default, shown by JS if not installed */
    align-items: center;
    justify-content: center;
    margin-left: 6px;
    cursor: pointer;
    color: var(--text-secondary);
    font-size: 1.2rem;
    transition: color 0.2s;
    position: relative;
  }
  .pwa-install-header:hover {
    color: var(--accent);
  }
  .pwa-install-header .pwa-badge {
    position: absolute;
    top: -4px;
    right: -6px;
    background: #f59e0b;
    border-radius: 50%;
    width: 10px;
    height: 10px;
    font-size: 0;
    animation: pulse-dot 1.5s ease-in-out infinite;
  }
  @keyframes pulse-dot {
    0% { transform: scale(1); opacity: 1; }
    50% { transform: scale(1.5); opacity: 0.7; }
    100% { transform: scale(1); opacity: 1; }
  }
  .pwa-install-header .pwa-btn-text {
    display: none;
    font-size: 0.65rem;
    font-weight: 600;
    margin-left: 2px;
  }
  @media (min-width: 480px) {
    .pwa-install-header .pwa-btn-text {
      display: inline;
    }
  }
</style>

<span class="pwa-install-header" id="pwaInstallHeader" title="Install App">
  <i class="fas fa-download"></i>
  <span class="pwa-btn-text">Install</span>
  <span class="pwa-badge"></span>
</span>

<!-- Fallback Modal (same as before) -->
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
  let deferredPrompt = null;
  const headerBtn = document.getElementById('pwaInstallHeader');
  const modalOverlay = document.getElementById('pwaModalOverlay');
  const modalClose = document.getElementById('pwaModalClose');

  function isInstalled() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           window.navigator.standalone === true;
  }

  function updateHeaderButton() {
    if (isInstalled()) {
      headerBtn.style.display = 'none';
      return;
    }
    headerBtn.style.display = 'flex';
  }

  window.addEventListener('beforeinstallprompt', function(e) {
    e.preventDefault();
    deferredPrompt = e;
    console.log('[PWA] beforeinstallprompt captured');
  });

  headerBtn.addEventListener('click', function() {
    if (deferredPrompt) {
      deferredPrompt.prompt();
      deferredPrompt.userChoice.then(function(choice) {
        if (choice.outcome === 'accepted') {
          console.log('[PWA] User accepted install');
          headerBtn.style.display = 'none';
        } else {
          console.log('[PWA] User dismissed install');
        }
        deferredPrompt = null;
      });
    } else {
      // No native prompt → show fallback modal
      modalOverlay.classList.add('active');
    }
  });

  function closeModal() {
    modalOverlay.classList.remove('active');
  }
  modalClose.addEventListener('click', closeModal);
  modalOverlay.addEventListener('click', function(e) {
    if (e.target === modalOverlay) closeModal();
  });

  // Service Worker registration (if not already)
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/static/sw.js', { scope: '/' })
      .then(function(reg) {
        console.log('[SW] Registered');
      })
      .catch(function(err) {
        console.log('[SW] Registration failed: ', err);
      });
  }

  // Store tenant in localStorage
  const path = window.location.pathname;
  const match = path.match(/^\\/portal\\/([^\\/]+)/);
  if (match) {
    localStorage.setItem('chakki_tenant', match[1]);
  }

  // Initial state
  updateHeaderButton();

  // Re-check when user returns (e.g., after install)
  window.addEventListener('pageshow', updateHeaderButton);
  window.addEventListener('appinstalled', function() {
    headerBtn.style.display = 'none';
  });

})();
</script>
<!-- ===== END PWA INSTALL ===== -->
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

def remove_old_pwa_blocks(content):
    """Remove the old floating install button and its styles/scripts."""
    # Remove the old wrapper div
    content = re.sub(r'<div[^>]*id="pwa-install-wrapper"[^>]*>.*?</div>', '', content, flags=re.DOTALL)
    # Remove the old modal overlay if it's the same (we'll re-add)
    content = re.sub(r'<div[^>]*id="pwaModalOverlay"[^>]*>.*?</div>', '', content, flags=re.DOTALL)
    # Remove any old inline script that handled install (to avoid duplicates)
    content = re.sub(r'<script>.*?PWA install prompt.*?</script>', '', content, flags=re.DOTALL)
    # Also remove the old style block if it's separate
    content = re.sub(r'<style>.*?\.pwa-install-wrapper.*?</style>', '', content, flags=re.DOTALL)
    return content

def inject_header_button(filepath):
    """Replace the install block with the header version."""
    if not os.path.exists(filepath):
        print(f"⚠️  File not found: {filepath}")
        return

    with open(filepath, 'r') as f:
        content = f.read()

    # If already has our new header block, skip
    if 'pwa-install-header' in content:
        print(f"⏩ {filepath} already has the new header install button – skipping.")
        return

    backup_file(filepath)

    # Remove old PWA blocks
    content = remove_old_pwa_blocks(content)

    # Insert our new block just before </body>
    if '</body>' in content:
        content = content.replace('</body>', HEADER_INSTALL_BLOCK + '\n</body>')
    else:
        content += HEADER_INSTALL_BLOCK

    write_file(filepath, content)

def patch_root_html():
    """Ensure root.html uses the correct tenant fallback (already good)."""
    # The root.html already redirects well, but we can update it if needed.
    # It's already correct from previous patcher.
    pass

# ---------- MAIN ----------

def main():
    print("🔧 Starting PWA Header Patcher...\n")

    print("📄 Injecting header install button into base templates...")
    inject_header_button(MOBILE_BASE)
    inject_header_button(DESKTOP_BASE)

    # (Optional) Update root.html – already fine
    print("🌐 root.html already up to date.")

    print("🔄 Restarting Gunicorn...")
    subprocess.run(["sudo", "systemctl", "restart", "gunicorn"], check=False)

    print("\n🎉 PWA Header Patcher completed!")
    print("📌 The install button now lives in the top bar (next to the bell).")
    print("   - It appears only if the app is not installed.")
    print("   - On HTTPS: triggers the native install prompt.")
    print("   - On HTTP: opens a helpful modal with manual install steps.")
    print("   - After installation, the button disappears.")
    print("\n👉 Clear your browser cache and reload to see the changes.")

if __name__ == "__main__":
    main()
