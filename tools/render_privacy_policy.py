"""Generate a public HTML policy and deletion guide from the in-app JSON asset."""
import html
import json
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--draft', action='store_true', help='Render a local review copy; not for publication')
args = parser.parse_args()
policy = json.loads((ROOT / 'apps/mobile/assets/legal/privacy_policy.json').read_text(encoding='utf-8'))
if not args.draft:
    assert 'CONTACT_PENDING' not in (policy['contact_label'], policy['contact_url']), 'Confirm a real privacy contact before publishing'
else:
    if policy['contact_url'] == 'CONTACT_PENDING':
        policy['contact_url'] = '#privacy-contact'
        policy['contact_label'] = 'Contact details awaiting confirmation'
output = ROOT / ('apps/mobile/build/privacy-policy-draft' if args.draft else 'web/legal')
output.mkdir(parents=True, exist_ok=True)
escape = html.escape

style = '''
:root{color-scheme:dark light}*{box-sizing:border-box}body{margin:0;background:#0b1020;color:#e5e7eb;font:16px/1.7 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
header,main,footer{max-width:920px;margin:auto;padding:24px}header{padding-top:40px;border-bottom:1px solid #334155}h1{font-size:clamp(28px,5vw,42px);line-height:1.2;margin:8px 0}h2{font-size:22px;line-height:1.4;margin-top:36px;color:#facc15}
a{color:#7dd3fc;overflow-wrap:anywhere}li{margin:12px 0}nav{display:flex;flex-wrap:wrap;gap:18px;margin:20px 0}.muted{color:#a8b3c7}.card{padding:18px;border:1px solid #334155;border-radius:14px;background:#131b2e}
footer{border-top:1px solid #334155;font-size:14px}a:focus-visible{outline:3px solid #facc15;outline-offset:4px}@media(prefers-color-scheme:light){body{background:#f8fafc;color:#172033}h2{color:#735000}a{color:#075985}.muted{color:#475569}.card{background:white}header,footer,.card{border-color:#cbd5e1}}
'''

def page(title, body):
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="{escape(title)} for Ludo Play. Learn about account, device, gameplay and purchase information and your privacy choices.">
<title>{escape(title)} | Ludo Play</title><style>{style}</style></head><body><!--email_off-->
<header><div class="muted">LUDO PLAY{' · DRAFT — NOT PUBLISHED' if args.draft else ''}</div><h1>{escape(title)}</h1><p class="muted">Updated {escape(policy['updated'])} · {escape(policy['package_name'])}</p>
<nav aria-label="Legal pages"><a href="/privacy-policy">Privacy Policy</a><a href="/delete-account">Delete Account &amp; Data</a></nav></header>
<main>{body}</main><footer id="privacy-contact">Privacy contact: <a href="{escape(policy['contact_url'], quote=True)}">{escape(policy['contact_label'])}</a><br>Ludo Play · {escape(policy['package_name'])}</footer>
<!--/email_off--></body></html>'''

sections = []
for section in policy['sections']:
    content = f"<section><h2>{escape(section['title'])}</h2>"
    for paragraph in section.get('paragraphs', []):
        content += f'<p>{escape(paragraph)}</p>'
    if section.get('bullets'):
        content += '<ul>' + ''.join(f'<li>{escape(item)}</li>' for item in section['bullets']) + '</ul>'
    sections.append(content + '</section>')
sections.append(f'''<section class="card"><h2>Privacy and account help</h2><p><a href="{escape(policy['contact_url'], quote=True)}">Contact: {escape(policy['contact_label'])}</a></p><p><a href="/delete-account">Request account deletion</a></p><p>Google services: <a href="https://policies.google.com/privacy">Google Privacy Policy</a>.</p></section>''')
(output / 'privacy-policy.html').write_text(page('Privacy Policy', ''.join(sections)), encoding='utf-8')

deletion = f'''<section><h2>Delete your Ludo Play account</h2><p>You can initiate deletion from the app or contact support from this page. You do not need to reinstall Ludo Play to send a request.</p>
<h2>In the app</h2><ol><li>Open Ludo Play and sign in to the account you want to delete.</li><li>Open Settings and select <strong>Delete Account &amp; Data</strong>.</li><li>Read the confirmation and confirm deletion. This cannot be undone.</li></ol>
<h2>Without the app</h2><p><a href="{escape(policy['contact_url'], quote=True)}">Contact {escape(policy['contact_label'])}</a> and use the subject <strong>Ludo Play account deletion</strong>. Provide your account email or username and state that you want the account and its associated data deleted. Support may verify ownership before processing.</p><p>Never provide your password, login token, Google password, or full payment details.</p>
<h2>What is deleted and what may remain</h2>'''
deletion += ''.join(f'<p>{escape(paragraph)}</p>' for paragraph in policy['sections'][7]['paragraphs'][1:])
deletion += '<p>Clearing app storage or uninstalling the app only removes local copies. It does not delete an online account. Deleting Ludo Play does not delete your Google account or Google Play payment history.</p><p><a href="/privacy-policy">Read the complete Privacy Policy</a></p></section>'
(output / 'delete-account.html').write_text(page('Delete Account & Data', deletion), encoding='utf-8')
print('Generated:', output / 'privacy-policy.html', output / 'delete-account.html')
