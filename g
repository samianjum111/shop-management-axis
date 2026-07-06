#!/usr/bin/env python3
"""
Diagnostic patch – makes the PWA install button highly visible and logs its status.
"""
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
TEMPLATES = PROJECT_ROOT / 'templates'

# New button HTML with diagnostic styling and logging
DIAGNOSTIC_BUTTON = '''
    <!-- PWA Install Button – DIAGNOSTIC VERSION -->
    <div id="pwa-install-btn" style="position:fixed; bottom:80px; right:16px; z-index:999999; background:red; border:5px solid yellow; padding:5px; border-radius:10px;">
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
        const installBtn = document.getElementById('pwa-install-btn');
        console.log('PWA Diagnostic: installBtn found?', installBtn);
        if (installBtn) {
            console.log('PWA Diagnostic: current display style:', window.getComputedStyle(installBtn).display);
        }

        let deferredPrompt = null;
        if (window.matchMedia('(display-mode: standalone)').matches) {
            if (installBtn) installBtn.style.display = 'none';
            console.log('PWA: Already installed (standalone).');
        }

        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            console.log('PWA: beforeinstallprompt fired.');
        });

        window.installApp = function() {
            if (deferredPrompt) {
                deferredPrompt.prompt();
                deferredPrompt.userChoice.then((choiceResult) => {
                    console.log('PWA: User choice:', choiceResult.outcome);
                    deferredPrompt = null;
                });
            } else {
                console.log('PWA: No deferredPrompt, showing manual hint.');
                alert('You can install this app by clicking the "Install" icon in the browser address bar.');
            }
        };

        window.addEventListener('appinstalled', () => {
            if (installBtn) installBtn.style.display = 'none';
            deferredPrompt = null;
            console.log('PWA: App installed.');
        });

        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('/static/sw.js')
                .then(reg => console.log('PWA: SW registered:', reg))
                .catch(err => console.log('PWA: SW registration failed:', err));
        }
    })();
    </script>
'''

def patch_file(filepath):
    if not filepath.exists():
        print(f"⚠️  {filepath} not found, skipping.")
        return
    content = filepath.read_text(encoding='utf-8')
    # Replace the entire install button block
    pattern = r'<!-- PWA Install Button.*?</script>'
    if re.search(pattern, content, re.DOTALL):
        content = re.sub(pattern, DIAGNOSTIC_BUTTON, content, flags=re.DOTALL)
        filepath.write_text(content, encoding='utf-8')
        print(f"✅ Patched {filepath}")
    else:
        print(f"⚠️  Could not find install button block in {filepath}, skipping.")

def main():
    for base in [TEMPLATES / 'mobile' / 'base.html', TEMPLATES / 'desktop' / 'base.html']:
        patch_file(base)

    print("\n📌 Next steps:")
    print("1. Run: python3 manage.py collectstatic --noinput")
    print("2. Restart your server")
    print("3. Open your site in the browser")
    print("4. Look at the bottom-right corner – you should see a RED box with an orange button.")
    print("5. Open the browser console (F12) and check the logs for diagnostic messages.")
    print("   - If the console says 'installBtn found? null', the button is not in the DOM.")
    print("   - If it says 'installBtn found? [object HTMLDivElement]' but you don't see it, it's hidden/covered.")

if __name__ == '__main__':
    main()
