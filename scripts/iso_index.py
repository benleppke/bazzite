#!/usr/bin/env python3
"""Render the ISO download page from the published index.

Usage: iso_index.py <index.json> <flavors.json>

Writes HTML to stdout. The input is bazzite/latest/index.json, which the
publish job assembles from the per-release manifest.json files, plus the
canonical flavor list, so the page, the netboot menu and the manifests cannot
disagree about what is published.

The page is a single self-contained file: no external stylesheet, font or
script. The publish job uploads exactly one object, and nothing can drift
between the page and the assets it would have loaded.

Design tokens are copied from the package repository landing page
(packages/assets/style.css) so the two sites read as one family. That file is
not fetched at build time: a page served from B2 must not depend on another
repository's pipeline to render.
"""

import datetime
import html
import json
import sys
import urllib.parse

# A flavor whose newest release is older than this is called out on the page.
# Weekly builds mean anything past ~10 days missed at least one week.
STALE_DAYS = 10

REPO_URL = "https://github.com/benleppke/bazzite"
SITE_URL = "https://benleppke.com/"
TITLE = "Bazzite Images"
SUBTITLE = "Bootable live ISOs for my customized Bazzite images, rebuilt weekly."
DESCRIPTION = (
    "Bootable live ISOs built weekly from Ben Leppke's customized Bazzite images."
)

CSS = """
:root {
  color-scheme: dark light;
  --bg: #181818;
  --fg: #d9d9d9;
  --heading: #ffffff;
  --muted: #a0a0a0;
  --card: #222222;
  --border: #353535;
  --accent: #8c96ff;
  --accent-contrast: #181818;
  --code-bg: #222222;
  --link: #8c96ff;
  --button-bg: #353535;
}

@media (prefers-color-scheme: light) {
  :root {
    --bg: #ffffff;
    --fg: #2d2d2d;
    --heading: #111111;
    --muted: #666666;
    --card: #f4f4f4;
    --border: #d4d4d4;
    --accent: #f89a20;
    --accent-contrast: #181818;
    --code-bg: #f4f4f4;
    --link: #f89a20;
    --button-bg: #e0e0e0;
  }
}

* { box-sizing: border-box; }

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
    Helvetica, Arial, sans-serif;
  background: var(--bg);
  color: var(--fg);
  line-height: 1.5;
}

.page-heading {
  max-width: 1080px;
  margin: 1.5rem auto 0;
  padding: 0 1.25rem;
}

h1 {
  margin: 0 0 0.25rem;
  color: var(--heading);
  font-size: 1.75rem;
}

.subtitle { margin: 0; color: var(--muted); }

main {
  max-width: 1080px;
  margin: 0 auto;
  padding: 0 1.25rem 3rem;
}

section { margin: 2rem 0; }

h2 {
  color: var(--heading);
  font-size: 1.2rem;
  border-bottom: 1px solid var(--border);
  padding-bottom: 0.4rem;
}

h3 {
  margin: 0 0 0.35rem;
  color: var(--heading);
  font-size: 1.05rem;
}

a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }

code {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.85rem;
}

.note {
  margin: 1.5rem 0 0;
  padding: 0.7rem 0.9rem;
  border-left: 3px solid var(--accent);
  background: var(--card);
  border-radius: 0 8px 8px 0;
  color: var(--muted);
  font-size: 0.9rem;
}

.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
  margin-top: 1.5rem;
}

.card {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  min-width: 0;
  padding: 1rem 1.1rem;
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 10px;
}

/* Cards in a row are the same height, but the descriptions wrap to a
   different number of lines. Let the description take the slack so the
   checksum and download button line up across the row at any width. */
.card-desc {
  flex-grow: 1;
  margin: 0;
  color: var(--muted);
  font-size: 0.9rem;
}

.card-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.6rem;
}

.card-head h3 { min-width: 0; }

.badges {
  display: flex;
  flex: none;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.35rem;
}

.badge {
  padding: 0.05rem 0.5rem;
  border: 1px solid var(--border);
  border-radius: 999px;
  color: var(--muted);
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.badge.warn { border-color: var(--accent); color: var(--accent); }

.card-meta {
  margin: 0;
  color: var(--fg);
  font-size: 0.9rem;
}

/* The full checksum is in the DOM and in data-copy. Cards use the .fill
   variant so the hash occupies the space up to the right-aligned Copy button
   and ellipsizes just before it, rather than wrapping to a second line. */
.hash-line {
  display: flex;
  align-items: flex-start;
  gap: 0.45rem;
  min-width: 0;
  margin: 0;
  color: var(--muted);
  font-size: 0.75rem;
}

.hash-label {
  flex: none;
  padding-top: 0.05rem;
  color: var(--muted);
  font-size: 0.66rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.hash-line code {
  flex: 0 1 auto;
  min-width: 0;
  color: var(--fg);
  font-size: 0.75rem;
  line-height: 1.4;
  overflow-wrap: anywhere;
  user-select: all;
}

.hash-line.fill code {
  flex: 1 1 auto;
  overflow: hidden;
  overflow-wrap: normal;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Keep the button the same width in every state so "Copy" -> "Copied" does
   not move the checksum or table columns. */
.copy-btn {
  flex: none;
  min-width: 5em;
  padding: 0.08rem 0.45rem;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--button-bg);
  color: var(--muted);
  font: inherit;
  font-size: 0.7rem;
  line-height: 1.5;
  text-align: center;
  white-space: nowrap;
  cursor: pointer;
}

.copy-btn:hover { color: var(--heading); border-color: var(--accent); }

.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.15rem;
}

.button {
  display: inline-block;
  padding: 0.55rem 0.9rem;
  border-radius: 8px;
  background: var(--accent);
  color: var(--accent-contrast);
  font-weight: 600;
  text-align: center;
}

.button:hover { text-decoration: none; filter: brightness(1.08); }

.card .button { flex: 1 1 auto; }

/* Code blocks have their own toolbar, so the copy button does not steal a
   column from the commands. Full-width blocks wrap long lines; the copy
   button still copies the exact text. */
.code-block {
  min-width: 0;
  margin-top: 0.15rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--code-bg);
  overflow: hidden;
}

.code-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.3rem 0.45rem 0.3rem 0.8rem;
  border-bottom: 1px solid var(--border);
  background: var(--card);
}

.code-title {
  color: var(--muted);
  font-size: 0.66rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.code-block pre {
  margin: 0;
  padding: 0.8rem 1rem;
  background: transparent;
  border: 0;
  border-radius: 0;
  overflow-wrap: anywhere;
  white-space: pre-wrap;
}

.code-block code {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.8rem;
  line-height: 1.55;
  white-space: pre-wrap;
}

/* One tab per flavor, plus All at the end. The radios are visually hidden but
   remain keyboard accessible. */
.verify-picker {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 1rem;
}

.verify-picker > input {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
  pointer-events: none;
}

.verify-picker > label {
  padding: 0.4rem 0.8rem;
  border: 1px solid var(--border);
  border-radius: 999px;
  background: var(--card);
  color: var(--muted);
  font-size: 0.9rem;
  cursor: pointer;
}

.verify-picker > label:hover {
  border-color: var(--accent);
  color: var(--heading);
}

.verify-picker > input:checked + label {
  border-color: var(--accent);
  background: var(--accent);
  color: var(--accent-contrast);
  font-weight: 600;
}

.verify-picker > input:focus-visible + label {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}

.verify-panels {
  flex-basis: 100%;
  min-width: 0;
}

.verify-panel { display: none; }

.panel-meta {
  margin: 0 0 0.45rem;
  color: var(--muted);
  font-size: 0.85rem;
}

.panel-meta strong { color: var(--heading); }

.table-wrap {
  margin-top: 0.75rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--card);
  overflow-x: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
  background: transparent;
}

th, td {
  padding: 0.6rem 0.9rem;
  border-bottom: 1px solid var(--border);
  text-align: left;
  vertical-align: top;
  overflow-wrap: break-word;
}

thead th {
  background: var(--button-bg);
  color: var(--muted);
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

tbody tr:last-child td { border-bottom: none; }

td.sha .hash-line { font-size: 0.74rem; }
td.sha .hash-line code { font-size: 0.74rem; }
td.sha .copy-btn { font-size: 0.66rem; }

td[data-label="Date"],
td[data-label="Size"] { white-space: nowrap; }

.iso-link { overflow-wrap: anywhere; }

footer {
  max-width: 1080px;
  margin: 0 auto;
  padding: 1.25rem;
  color: var(--muted);
  font-size: 0.85rem;
}

.footer-content { text-align: center; }
.copyright { margin-top: 0; font-size: 14px; color: var(--muted); }
.copyright a { color: var(--link); }

@media (max-width: 720px) {
  .cards { grid-template-columns: 1fr; }

  .code-block pre,
  .code-block code {
    overflow-wrap: anywhere;
    white-space: pre-wrap;
  }

  /* A full checksum that is not in a card gets a header row: label and Copy
     first, then the hash across full-width lines. Card hashes stay inline
     and ellipsize. */
  .hash-line:not(.fill):not(.short) { flex-wrap: wrap; }
  .hash-line:not(.fill):not(.short) .hash-label { order: 1; }
  .hash-line:not(.fill):not(.short) .copy-btn {
    order: 2;
    margin-left: auto;
  }
  .hash-line:not(.fill):not(.short) code {
    order: 3;
    flex-basis: 100%;
  }

  .table-wrap { overflow-x: visible; }
  thead { display: none; }

  table, tbody, tr, td { display: block; }

  tbody tr {
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--border);
  }

  tbody tr:last-child { border-bottom: none; }

  td { padding: 0.1rem 0.9rem; border-bottom: none; }

  td::before {
    content: attr(data-label) " ";
    color: var(--muted);
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
}
"""

SCRIPT = """
document.querySelectorAll(".copy-btn").forEach(function (btn) {
  btn.addEventListener("click", function () {
    var host = btn.closest(".copyable, .code-block");
    var code = host ? host.querySelector("code") : null;
    if (!code) return;
    var text = host.getAttribute("data-copy") || code.textContent.trim();
    var old = btn.textContent;
    var done = function (label) {
      btn.textContent = label;
      setTimeout(function () { btn.textContent = old; }, 1400);
    };
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).then(
        function () { done("Copied"); },
        function () { done("Failed"); }
      );
    } else {
      var range = document.createRange();
      range.selectNodeContents(code);
      var selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      done("Select");
    }
  });
});
"""


def esc(value):
    return html.escape(str(value), quote=True)


def human_size(size):
    """Bytes to a decimal size: ISO images ship as decimal GB."""
    try:
        size = int(size)
    except (TypeError, ValueError):
        return "unknown size"
    if size >= 1_000_000_000:
        return f"{size / 1_000_000_000:.1f} GB"
    if size >= 1_000_000:
        return f"{size / 1_000_000:.0f} MB"
    if size >= 1_000:
        return f"{size / 1_000:.0f} kB"
    return f"{size} B"


def fmt_stamp(value):
    """Render an ISO 8601 timestamp as 'YYYY-MM-DD HH:MM UTC'."""
    if not value:
        return "unknown"
    try:
        stamp = datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return str(value)
    if stamp.tzinfo is not None:
        stamp = stamp.astimezone(datetime.timezone.utc)
    return stamp.strftime("%Y-%m-%d %H:%M UTC")


def short_sha(value):
    if not value:
        return ""
    value = str(value)
    return value if len(value) <= 16 else f"{value[:16]}…"


def site_url(base_url):
    """The host root, where the Cloudflare rewrite serves this page.

    base_url is the artifact prefix (https://host/bazzite), not the page's
    canonical location, so derive the origin instead of guessing.
    """
    parts = urllib.parse.urlsplit(base_url)
    if not parts.scheme or not parts.netloc:
        return base_url
    return f"{parts.scheme}://{parts.netloc}/"


def copy_btn(aria="Copy"):
    return (
        f'<button class="copy-btn" type="button" aria-label="{esc(aria)}">Copy</button>'
    )


def wrap_hash(value):
    """Break a full checksum at 32 characters for narrow full-width layouts."""
    value = str(value or "")
    if len(value) > 32:
        return f"{esc(value[:32])}<wbr>{esc(value[32:])}"
    return esc(value)


def hash_contents(sha, aria, show_label=True, short=False, wrap=True):
    text = str(sha or "")
    label = '<span class="hash-label">SHA-256</span>' if show_label else ""
    if not text:
        return f"{label}<code>unavailable</code>"
    if short:
        shown = esc(short_sha(text))
    elif wrap:
        shown = wrap_hash(text)
    else:
        shown = esc(text)
    return f'{label}<code title="{esc(text)}">{shown}</code>{copy_btn(aria=aria)}'


def hash_line(sha, aria, fill=False, short=False):
    """A checksum with a copy button. Cards use fill=True."""
    text = str(sha or "")
    classes = "hash-line copyable"
    if fill:
        classes += " fill"
    if short:
        classes += " short"
    data = f' data-copy="{esc(text)}"' if text else ""
    return (
        f'<p class="{classes}"{data}>'
        f"{hash_contents(sha, aria, short=short, wrap=not fill)}</p>"
    )


def hash_inline(sha, aria, short=False):
    text = str(sha or "")
    classes = "hash-line copyable"
    if short:
        classes += " short"
    data = f' data-copy="{esc(text)}"' if text else ""
    return (
        f'<span class="{classes}"{data}>'
        f"{hash_contents(sha, aria, show_label=False, short=short)}</span>"
    )


def code_block(command, title):
    return (
        '<div class="code-block">'
        f'<div class="code-head"><span class="code-title">{esc(title)}</span>'
        f"{copy_btn(aria='Copy commands')}</div>"
        f"<pre><code>{esc(command)}</code></pre>"
        "</div>"
    )


def verify_commands(base_url, iso_name):
    """Keep each line short enough to read inside the page."""
    return "\n".join(
        [
            f"base={base_url}/latest",
            f"iso={iso_name}",
            'curl -LO "$base/$iso" "$base/$iso.sha256" "$base/$iso.sha256.bundle"',
            'curl -LO "$base/cosign.pub"',
            'sha256sum -c "$iso.sha256"',
            "cosign verify-blob --key cosign.pub \\",
            '  --bundle "$iso.sha256.bundle" "$iso.sha256"',
        ]
    )


def aggregate_command(base_url):
    return "\n".join(
        [
            f"base={base_url}/latest",
            'curl -LO "$base/SHA256SUMS" "$base/SHA256SUMS.bundle" "$base/cosign.pub"',
            "cosign verify-blob --key cosign.pub \\",
            "  --bundle SHA256SUMS.bundle SHA256SUMS",
            "sha256sum -c SHA256SUMS",
        ]
    )


def releases(flavor_entry):
    """date -> manifest, newest first, dropping empty entries."""
    entries = (flavor_entry or {}).get("releases") or {}
    pairs = [(str(date), manifest) for date, manifest in entries.items() if manifest]
    return sorted(pairs, key=lambda pair: pair[0], reverse=True)


def days_old(date, reference):
    try:
        return (reference - datetime.date.fromisoformat(date)).days
    except (TypeError, ValueError):
        return None


def iso_url(base_url, date, manifest):
    urls = manifest.get("urls") or {}
    if urls.get("iso"):
        return urls["iso"]
    return f"{base_url}/live/{date}/{(manifest.get('iso') or {}).get('name', '')}"


def badge_html(flavor, date, reference):
    badges = []
    if flavor.get("badge"):
        badges.append(f'<span class="badge">{esc(flavor["badge"])}</span>')
    age = days_old(date, reference)
    if age is not None and age > STALE_DAYS:
        badges.append(f'<span class="badge warn">built {age} days ago</span>')
    if not badges:
        return ""
    return '<span class="badges">' + "".join(badges) + "</span>"


def latest_release(base_url, flavor, entry):
    pairs = releases(entry)
    if not pairs:
        return None
    date, manifest = pairs[0]
    iso = manifest.get("iso") or {}
    iso_name = iso.get("name") or f"{flavor['name']}-live-amd64.iso"
    return {
        "date": date,
        "manifest": manifest,
        "iso": iso,
        "iso_name": iso_name,
        "sha": iso.get("sha256") or "",
        "download": f"{base_url}/latest/{iso_name}",
    }


def render_card(base_url, flavor, entry, reference):
    pairs = releases(entry)
    if not pairs:
        return f"""<article class="card">
  <div class="card-head">
    <h3>{esc(flavor["display"])}</h3>
    {badge_html(flavor, "", reference)}
  </div>
  <p class="card-desc">{esc(flavor.get("description", ""))}</p>
  <p class="card-meta">No build published yet.</p>
</article>"""

    info = latest_release(base_url, flavor, entry)
    return f"""<article class="card">
  <div class="card-head">
    <h3>{esc(flavor["display"])}</h3>
    {badge_html(flavor, info["date"], reference)}
  </div>
  <p class="card-desc">{esc(flavor.get("description", ""))}</p>
  <p class="card-meta">{esc(info["date"])} · {esc(human_size(info["iso"].get("size")))}</p>
  {hash_line(info["sha"], f"Copy SHA-256 checksum for {info["iso_name"]}", fill=True)}
  <div class="actions">
    <a class="button" href="{esc(info["download"])}">Download ISO</a>
  </div>
</article>"""


def verify_tab_css(flavors):
    rules = []
    for flavor in flavors:
        name = flavor["name"]
        rules.append(
            f"#verify-{name}:checked ~ .verify-panels #panel-{name} "
            "{ display: block; }"
        )
    rules.append("#verify-all:checked ~ .verify-panels #panel-all { display: block; }")
    return "\n".join(rules)


def verify_panel(base_url, flavor, entry):
    info = latest_release(base_url, flavor, entry)
    if info is None:
        return '<p class="card-desc">No build published yet.</p>'
    return (
        f'<p class="panel-meta"><strong>{esc(info["iso_name"])}</strong> · '
        f"built {esc(info['date'])} · "
        f"{esc(human_size(info['iso'].get('size')))}</p>"
        f"{hash_line(info['sha'], f'Copy SHA-256 checksum for {info["iso_name"]}')}"
        f"{code_block(verify_commands(base_url, info['iso_name']), 'Linux shell')}"
    )


def render_verify(base_url, flavors, entries, aggregate):
    controls = []
    panels = []

    for index, flavor in enumerate(flavors):
        name = flavor["name"]
        checked = " checked" if index == 0 else ""
        controls.append(
            f'<input type="radio" name="verify-flavor" '
            f'id="verify-{esc(name)}"{checked}>'
            f'<label for="verify-{esc(name)}">{esc(flavor["display"])}</label>'
        )
        panels.append(
            f'<div class="verify-panel" id="panel-{esc(name)}">'
            f"{verify_panel(base_url, flavor, entries.get(name))}</div>"
        )

    all_checked = " checked" if not flavors else ""
    controls.append(
        '<input type="radio" name="verify-flavor" '
        f'id="verify-all"{all_checked}><label for="verify-all">All</label>'
    )
    panels.append(
        '<div class="verify-panel" id="panel-all">'
        '<p class="card-desc"><code>SHA256SUMS</code> covers every published '
        "flavor and is signed as a single file. Download all the ISOs into one "
        "directory first, then run this there.</p>"
        f"{code_block(aggregate, 'All flavors')}</div>"
    )

    return f"""<section id="verify">
  <h2>Verify a download</h2>
  <div class="verify-picker">
    {"".join(controls)}
    <div class="verify-panels">{"".join(panels)}</div>
  </div>
</section>"""


def render_earlier(base_url, flavors, index):
    rows = []
    for flavor in flavors:
        name = flavor["name"]
        pairs = releases((index.get("flavors") or {}).get(name))
        for date, manifest in pairs[1:]:
            iso = manifest.get("iso") or {}
            iso_name = iso.get("name") or name
            link = iso_url(base_url, date, manifest)
            sha = iso.get("sha256") or ""
            rows.append(
                "<tr>"
                f'<td data-label="Date">{esc(date)}</td>'
                f'<td data-label="Flavor">{esc(flavor["display"])}</td>'
                f'<td data-label="Size">{esc(human_size(iso.get("size")))}</td>'
                f'<td data-label="Download"><a class="iso-link" '
                f'href="{esc(link)}">{esc(iso_name)}</a></td>'
                f'<td class="sha" data-label="SHA256">'
                f"{hash_inline(sha, f'Copy SHA-256 checksum for {iso_name}', short=True)}"
                "</td>"
                "</tr>"
            )

    if not rows:
        return (
            '<p class="note">Every release is currently the newest one for its '
            "flavor. Earlier builds appear here while they are inside the "
            "four week retention window.</p>"
        )

    return f"""<div class="table-wrap">
  <table>
    <thead>
      <tr><th>Date</th><th>Flavor</th><th>Size</th><th>Download</th><th>SHA256</th></tr>
    </thead>
    <tbody>
{chr(10).join(rows)}
    </tbody>
  </table>
</div>"""


def render_netboot(base_url, flavors, index):
    """One worked example; the manifests carry the exact URLs per flavor."""
    example = None
    for flavor in flavors:
        pairs = releases((index.get("flavors") or {}).get(flavor["name"]))
        if pairs:
            example = (flavor, pairs[0][1])
            break

    if example is None:
        return "<p>No release is published yet.</p>"

    flavor, manifest = example
    netboot = manifest.get("netboot") or {}
    kernel_args = netboot.get("kernel_args") or "rd.live.image enforcing=0 quiet"
    prefix = f"{base_url}/latest/netboot/{flavor['name']}"
    kernel = (
        f"kernel {prefix}/vmlinuz initrd=initrd.img "
        f"root=live:{prefix}/squashfs.img rd.neednet=1 ip=dhcp {kernel_args}"
    )
    command = "\n".join([kernel, f"initrd {prefix}/initrd.img"])

    return f"""<p class="card-desc">
  Example for {esc(flavor["display"])}. The kernel, initrd and squashfs below
  are the same artefacts the ISO boots, extracted at build time. Each release
  also publishes a <code>manifest.json</code> with the exact URLs and hashes.
</p>
{code_block(command, "iPXE over HTTP(S)")}
<p class="card-desc">
  This downloads the whole squashfs into the initramfs; use at least 16 GB of
  RAM on the target. The
  <a href="{esc(base_url)}/latest/menu.ipxe">generated iPXE menu</a> lists every
  published flavor and the older releases still inside the retention window.
</p>"""


def render(index, flavors):
    base_url = str(index.get("base_url") or "https://isos.benleppke.com/bazzite")
    base_url = base_url.rstrip("/")
    generated = index.get("generated_at") or ""
    stamp = fmt_stamp(generated)
    year = datetime.datetime.now().year

    try:
        reference = datetime.datetime.fromisoformat(
            str(generated).replace("Z", "+00:00")
        ).date()
    except ValueError:
        reference = datetime.date.today()

    entries = index.get("flavors") or {}
    cards = "\n".join(
        render_card(base_url, flavor, entries.get(flavor["name"]), reference)
        for flavor in flavors
    )
    aggregate = aggregate_command(base_url)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{esc(TITLE)} · Ben Leppke</title>
  <meta name="description" content="{esc(DESCRIPTION)}">
  <meta property="og:title" content="{esc(TITLE)} · Ben Leppke">
  <meta property="og:description" content="{esc(DESCRIPTION)}">
  <meta property="og:url" content="{esc(site_url(base_url))}">
  <meta property="og:type" content="website">
  <meta name="twitter:card" content="summary">
  <link rel="canonical" href="{esc(site_url(base_url))}">
  <link rel="alternate" type="application/json"
        href="{esc(base_url)}/latest/index.json"
        title="Machine-readable release index">
  <style>{CSS}
{verify_tab_css(flavors)}</style>
</head>
<body>
  <div class="page-heading">
    <h1>{esc(TITLE)}</h1>
    <p class="subtitle">{esc(SUBTITLE)}</p>
  </div>
  <main>
    <p class="note">
      These images are tuned to my own workflow and tastes, and they change
      without notice. They are published for my own convenience; treat them as
      a worked example rather than a distribution. Dated builds are kept for
      four weeks, and <code>latest</code> always points at the most recent
      successful build.
    </p>

    <div class="cards">
{cards}
    </div>

    {render_verify(base_url, flavors, entries, aggregate)}

    <section id="netboot">
      <h2>Netboot</h2>
      {render_netboot(base_url, flavors, index)}
    </section>

    <section id="earlier">
      <h2>Earlier builds</h2>
      {render_earlier(base_url, flavors, index)}
    </section>
  </main>
  <footer id="footer">
    <div class="footer-content">
      <div class="copyright">
        &copy; {year} <a href="{esc(SITE_URL)}">Ben Leppke</a>
        · <a href="{esc(REPO_URL)}">Source</a>
        · <a href="{esc(REPO_URL)}/issues">Report an issue</a>
      </div>
      <p class="meta">Generated {esc(stamp)}</p>
    </div>
  </footer>
  <script>{SCRIPT}</script>
</body>
</html>
"""


def main(argv):
    if len(argv) != 3:
        print(f"usage: {argv[0]} <index.json> <flavors.json>", file=sys.stderr)
        return 2

    with open(argv[1], encoding="utf-8") as handle:
        index = json.load(handle)
    with open(argv[2], encoding="utf-8") as handle:
        flavors = json.load(handle).get("flavors") or []

    page = render(index, flavors)
    sys.stdout.write(page)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
