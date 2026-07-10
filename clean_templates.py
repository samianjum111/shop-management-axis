#!/usr/bin/env python3
"""
Sab PWA garbage remove karein aur sirf clean header button daalein.
"""
import os
import re
import shutil
import subprocess

BASE = "/var/www/shop-management-axis"
TEMPLATES = os.path.join(BASE, "templates")
MOBILE = os.path.join(TEMPLATES, "mobile", "base.html")
DESKTOP = os.path.join(TEMPLATES, "desktop", "base.html")

# ----- Clean PWA Block (sirf ek baar) -----
CLEAN_PWA = '''
<!-- ===== PWA INSTALL (Header Button) ===== -->
<style>
  .pwa-install-header {
    display: none;
    align-items: center;
    margin-left: 6px;
    cursor: pointer;
    color: var(--text-secondary);
    font-size: 1.2rem;
    position: relative;
  }
  .pwa-install-header:hover { color: var(--accent); }
  .pwa-install-header .pwa-badge {
    position: absolute; top: -4px; right: -6px;
    background: #f59e0b; border-radius: 50%; width: 10px; height: 10px;
    animation: pulse-dot 1.5s infinite;
  }
  @keyframes pulse-dot { 50% { transform: scale(1.5); opacity: 0.7; } }
  .pwa-install-header .pwa-btn-text {
    display: none; font-size: 0.65rem; font-weight: 600; margin-left: 2px;
  }
  @media (min-width: 480px) { .pwa-install-header .pwa-btn-text { display: inline; } }
  .pwa-modal-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.5); backdrop-filter: blur(6px);
    z-index: 10000; display: none; align-items: center; justify-content: center; padding: 20px;
  }
  .pwa-modal-overlay.active { display: flex; }
  .pwa-modal-box {
    background: #fff; border-radius: 24px; max-width: 380px; width: 100%;
    padding: 28px 24px 20px; box-shadow: 0 24px 64px rgba(0,0,0,0.3);
    color: #1a1a2e;
  }
  .pwa-modal-box h3 { margin: 0 0 4px; font-size: 1.3rem; font-weight: 700; }
  .pwa-modal-box p { font-size: 0.95rem; color: #4a5568; margin: 6px 0 16px; line-height: 1.5; }
  .pwa-modal-box .step { display: flex; align-items: center; gap: 10px; margin: 10px 0; font-size: 0.9rem; }
  .pwa-modal-box .step .num {
    background: #e2e8f0; border-radius: 50%; width: 28px; height: 28px;
    display: flex; align-items: center; justify-content: center; font-weight: 700; color: #2d3748;
    flex-shrink: 0;
  }
  .pwa-modal-box .btn-close-modal {
    background: #1a2a3a; color: #fff; border: none; border-radius: 40px;
    padding: 10px 0; width: 100%; font-weight: 600; font-size: 1rem; cursor: pointer; margin-top: 12px;
  }
</style>

<span class="pwa-install-header" id="pwaInstallHeader" title="Install App">
  <i class="fas fa-download"></i>
  <span class="pwa-btn-text">Install</span>
  <span class="pwa-badge"></span>
</span>

<div class="pwa-modal-overlay" id="pwaModalOverlay">
  <div class="pwa-modal-box">
    <h3>📲 Install this app</h3>
    <p>Add this app to your home screen.</p>
    <div class="step"><span class="num">1</span> Tap the share icon <i class="fas fa-share-alt" style="color:#2563eb;"></i></div>
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
    return window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  }

  function updateHeaderButton() {
    if (isInstalled()) { headerBtn.style.display = 'none'; return; }
    headerBtn.style.display = 'flex';
  }

  window.addEventListener('beforeinstallprompt', function(e) {
    e.preventDefault();
    deferredPrompt = e;
  });

  headerBtn.addEventListener('click', function() {
    if (deferredPrompt) {
      deferredPrompt.prompt();
      deferredPrompt.userChoice.then(function(choice) {
        if (choice.outcome === 'accepted') headerBtn.style.display = 'none';
        deferredPrompt = null;
      });
    } else {
      modalOverlay.classList.add('active');
    }
  });

  function closeModal() { modalOverlay.classList.remove('active'); }
  modalClose.addEventListener('click', closeModal);
  modalOverlay.addEventListener('click', function(e) {
    if (e.target === modalOverlay) closeModal();
  });

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/static/sw.js', { scope: '/' })
      .then(() => console.log('[SW] Registered'))
      .catch(() => console.log('[SW] Registration failed'));
  }

  const path = window.location.pathname;
  const match = path.match(/^\\/portal\\/([^\\/]+)/);
  if (match) localStorage.setItem('chakki_tenant', match[1]);

  updateHeaderButton();
  window.addEventListener('pageshow', updateHeaderButton);
  window.addEventListener('appinstalled', function() {
    headerBtn.style.display = 'none';
  });
})();
</script>
<!-- ===== END PWA ===== -->
'''

def clean_file(filepath):
    if not os.path.exists(filepath):
        return
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Remove ALL old PWA-related blocks (any variation)
    content = re.sub(r'<!-- ===== PWA INSTALL.*?-->.*?<!-- ===== END PWA.*?-->', '', content, flags=re.DOTALL)
    content = re.sub(r'<div[^>]*id="pwa-install-wrapper"[^>]*>.*?</div>', '', content, flags=re.DOTALL)
    content = re.sub(r'<div[^>]*id="pwaModalOverlay"[^>]*>.*?</div>', '', content, flags=re.DOTALL)
    content = re.sub(r'<style>.*?\.pwa-install-wrapper.*?</style>', '', content, flags=re.DOTALL)
    content = re.sub(r'<script>.*?let deferredPrompt = null;.*?</script>', '', content, flags=re.DOTALL)
    # Remove any standalone raw text like "2 Select “Add to Home Screen”" (if any)
    content = re.sub(r'\d+\s*Select\s*[“"]Add to Home Screen[”"]', '', content)
    content = re.sub(r'\d+\s*Tap\s*[“"]Add[”"]', '', content)
    # Remove any leftover "Add to Home Screen" text in HTML
    content = re.sub(r'<[^>]*>.*?Add to Home Screen.*?</[^>]*>', '', content, flags=re.DOTALL)

    # Backup
    shutil.copy2(filepath, filepath + '.bak')

    # Insert clean block before </body>
    if '</body>' in content:
        content = content.replace('</body>', CLEAN_PWA + '\n</body>')
    else:
        content += CLEAN_PWA

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"✅ Cleaned {filepath}")

# Clean both
clean_file(MOBILE)
clean_file(DESKTOP)

# Restart Gunicorn
subprocess.run(["sudo", "systemctl", "restart", "gunicorn"], check=False)

print("\n🎉 Templates cleaned and Gunicorn restarted.")
print("👉 Now clear browser cache (Ctrl+Shift+Delete) and reload with Ctrl+Shift+R.")
