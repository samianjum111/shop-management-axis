#!/usr/bin/env python3
"""
Force the PWA install button to be always visible (unless already installed).
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
TEMPLATES = PROJECT_ROOT / 'templates'

# The new install button HTML – we'll replace the old one entirely.
NEW_BUTTON_HTML = '''
    <!-- PWA Install Button & Service Worker -->
    <div id="pwa-install-btn" style="position:fixed; bottom:80px; right:16px; z-index:9999;">
        <button onclick="installApp()" style="
            background: #E67E22;
            color: white;
            border: none;
            border-radius: 50px;
            padding: 10px 18px;
            font-size: 0.85rem;
            font-weight: 600;
            box-shadow: 0 4px 14px rgba(230,126,34,0.4);
            display: flex;
            align-items: center;
            gap: 8px;
            cursor: pointer;
            transition: transform 0.2s;
            border: 1px solid rgba(255,255,255,0.2);
        ">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 5v14M5 12h14"/>
            </svg>
            Install App
        </button>
    </div>

    <script>
    (function() {
        'use strict';

        let deferredPrompt = null;
        const installBtn = document.getElementById('pwa-install-btn');

        // Hide if already installed (standalone mode)
        if (window.matchMedia('(display-mode: standalone)').matches) {
            installBtn.style.display = 'none';
            console.log('PWA: Already installed (standalone).');
        }

        // Listen for beforeinstallprompt
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            // Keep the button visible (already visible)
            console.log('PWA: beforeinstallprompt fired.');
        });

        // Install function
        window.installApp = function() {
            if (deferredPrompt) {
                deferredPrompt.prompt();
                deferredPrompt.userChoice.then((choiceResult) => {
                    if (choiceResult.outcome === 'accepted') {
                        console.log('PWA: User accepted the install prompt');
                    } else {
                        console.log('PWA: User dismissed the install prompt');
                    }
                    deferredPrompt = null;
                });
            } else {
                // If no deferredPrompt, try to use the browser's native install (Chrome only)
                console.log('PWA: No deferredPrompt, showing manual install hint.');
                alert('You can install this app by clicking the "Install" icon in the browser address bar.');
            }
        };

        // Hide after installation
        window.addEventListener('appinstalled', () => {
            installBtn.style.display = 'none';
            deferredPrompt = null;
            console.log('PWA: App installed.');
        });

        // Register service worker
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('/static/sw.js')
                .then(reg => console.log('PWA: SW registered:', reg))
                .catch(err => console.log('PWA: SW registration failed:', err));
        } else {
            console.log('PWA: Service workers not supported.');
        }
    })();
    </script>
'''

def patch_file(filepath):
    if not filepath.exists():
        print(f"⚠️  {filepath} not found, skipping.")
        return
    content = filepath.read_text(encoding='utf-8')
    # Find the existing install button block (from <!-- PWA Install Button --> to its closing </script>)
    # We'll replace everything between the markers.
    import re
    pattern = r'<!-- PWA Install Button & Service Worker -->.*?</script>'
    if re.search(pattern, content, re.DOTALL):
        content = re.sub(pattern, NEW_BUTTON_HTML, content, flags=re.DOTALL)
        filepath.write_text(content, encoding='utf-8')
        print(f"✅ Patched {filepath}")
    else:
        print(f"⚠️  Could not find install button block in {filepath}, skipping.")

def main():
    for base in [TEMPLATES / 'mobile' / 'base.html', TEMPLATES / 'desktop' / 'base.html']:
        patch_file(base)

    print("\n📌 Next steps:")
    print("1. Run: python3 manage.py collectstatic --noinput")
    print("2. Restart your server (Ctrl+C then run again)")
    print("3. Open the page and the button should be visible at the bottom-right.")
    print("   If it's still not visible, check the browser console for errors.")

if __name__ == '__main__':
    main()
