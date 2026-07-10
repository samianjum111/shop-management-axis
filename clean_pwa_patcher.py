#!/usr/bin/env python3
"""
Clean PWA Patcher – removes all old install blocks and injects the header button only.
"""

import os
import re
import shutil
import subprocess

BASE_DIR = "/var/www/shop-management-axis"
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

MOBILE_BASE = os.path.join(TEMPLATES_DIR, "mobile", "base.html")
DESKTOP_BASE = os.path.join(TEMPLATES_DIR, "desktop", "base.html")

# ---------- CLEAN HEADER INSTALL BLOCK (no duplicates) ----------
HEADER_INSTALL_BLOCK = '''
<!-- ===== PWA INSTALL (Header Button) ===== -->
<style>
  .pwa-install-header {
    display: none;
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
  /* Modal styles (fallback) */
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

<span class="pwa-install-header" id="pwaInstallHeader" title="Install App">
  <i class="fas fa-download"></i>
  <span class="pwa-btn-text">Install</span>
  <span class="pwa-badge"></span>
</span>

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

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/static/sw.js', { scope: '/' })
      .then(function(reg) { console.log('[SW] Registered'); })
      .catch(function(err) { console.log('[SW] Registration failed: ', err); });
  }

  // Store tenant in localStorage for root redirect
  const path = window.location.pathname;
  const match = path.match(/^\\/portal\\/([^\\/]+)/);
  if (match) {
    localStorage.setItem('chakki_tenant', match[1]);
  }

  updateHeaderButton();
  window.addEventListener('pageshow', updateHeaderButton);
  window.addEventListener('appinstalled', function() {
    headerBtn.style.display = 'none';
  });
})();
</script>
<!-- ===== END PWA INSTALL ===== -->
'''

# ---------- CLEANUP FUNCTIONS ----------

def backup_file(path):
    if os.path.exists(path):
        shutil.copy2(path, path + '.bak')
        print(f"📦 Backed up: {path}")

def remove_old_pwa_blocks(content):
    """Remove all traces of old PWA install blocks (floating, modal, styles, scripts)."""
    # Patterns to remove
    patterns = [
        r'<div[^>]*id="pwa-install-wrapper"[^>]*>.*?</div>',                 # old floating wrapper
        r'<div[^>]*id="pwaModalOverlay"[^>]*>.*?</div>',                    # old modal (we'll re-add)
        r'<style>.*?\.pwa-install-wrapper.*?</style>',                      # old style
        r'<script>.*?PWA install prompt.*?</script>',                       # old script (with that text)
        r'<script>.*?let deferredPrompt = null;.*?</script>',               # generic old script (fallback)
        r'<!-- ===== PWA INSTALL .*? ===== -->.*?<!-- ===== END PWA INSTALL ===== -->',  # any old block markers
    ]
    for pat in patterns:
        content = re.sub(pat, '', content, flags=re.DOTALL | re.IGNORECASE)
    return content

def inject_header_button(filepath):
    """Clean file and inject the header button."""
    if not os.path.exists(filepath):
        print(f"⚠️  File not found: {filepath}")
        return

    with open(filepath, 'r') as f:
        content = f.read()

    # Remove all old PWA blocks
    content = remove_old_pwa_blocks(content)

    # If the new header block is already present, remove it to avoid duplication (safe)
    content = re.sub(r'<!-- ===== PWA INSTALL \(Header Button\) ===== -->.*?<!-- ===== END PWA INSTALL ===== -->',
                     '', content, flags=re.DOTALL)

    # Insert our clean block just before </body>
    if '</body>' in content:
        content = content.replace('</body>', HEADER_INSTALL_BLOCK + '\n</body>')
    else:
        content += HEADER_INSTALL_BLOCK

    # Write back
    backup_file(filepath)
    with open(filepath, 'w') as f:
        f.write(content)
    print(f"✅ Updated: {filepath}")

# ---------- MAIN ----------

def main():
    print("🧹 Starting Clean PWA Patcher...\n")
    print("This will remove ALL old install blocks and inject the header button only.\n")

    print("📄 Processing mobile base...")
    inject_header_button(MOBILE_BASE)

    print("📄 Processing desktop base...")
    inject_header_button(DESKTOP_BASE)

    print("🔄 Restarting Gunicorn...")
    subprocess.run(["sudo", "systemctl", "restart", "gunicorn"], check=False)

    print("\n✅ Done! The install button now lives in the top bar (next to the bell).")
    print("   - It only appears if the app is not installed.")
    print("   - On HTTPS: triggers the native prompt.")
    print("   - On HTTP: shows the fallback modal with instructions.")
    print("   - After installation, the button disappears.\n")
    print("👉 Clear your browser cache and reload to see the clean version.")

if __name__ == "__main__":
    main()
