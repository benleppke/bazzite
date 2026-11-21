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
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
  margin-top: 1.5rem;
}

.card {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1rem 1.1rem;
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 8px;
}

.card-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.6rem;
}

.badge {
  flex: none;
  padding: 0.05rem 0.5rem;
  border: 1px solid var(--border);
  border-radius: 999px;
  color: var(--muted);
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.badge.warn { border-color: var(--accent); color: var(--accent); }

.card-desc { margin: 0; color: var(--muted); font-size: 0.9rem; }

.card-meta {
  margin: 0;
  color: var(--fg);
  font-size: 0.9rem;
}

.card-sha {
  margin: 0;
  color: var(--muted);
  font-size: 0.75rem;
  overflow-wrap: anywhere;
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

.card .button { margin-top: 0.15rem; }

details { margin-top: 0.25rem; }

summary {
  cursor: pointer;
  color: var(--muted);
  font-size: 0.9rem;
}

pre {
  background: var(--code-bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 0.9rem 1.1rem;
  overflow-x: auto;
}

code {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.85rem;
}

.install-wrap {
  position: relative;
  margin-top: 0.6rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--code-bg);
  overflow: hidden;
}

.install-wrap pre.install {
  margin: 0;
  padding: 0.8rem 4.2rem 0.8rem 1rem;
  background: transparent;
  border: 0;
  border-radius: 0;
}

.copy-btn {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  padding: 0.15rem 0.45rem;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--card);
  color: var(--muted);
  font-size: 0.7rem;
  line-height: 1.4;
  cursor: pointer;
}

.copy-btn:hover { color: var(--heading); border-color: var(--accent); }

.table-wrap {
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
  background: var(--card);
  margin-top: 0.75rem;
}

table {
  width: 100%;
  border-collapse: collapse;
  background: transparent;
}

th, td {
  text-align: left;
  padding: 0.6rem 0.9rem;
  border-bottom: 1px solid var(--border);
  overflow-wrap: break-word;
}

thead th {
  color: var(--muted);
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  background: var(--button-bg);
}

tbody tr:last-child td { border-bottom: none; }

td.sha {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.8rem;
  color: var(--muted);
}

@media (max-width: 600px) {
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
"""

SCRIPT = """
document.querySelectorAll(".copy-btn").forEach(function (btn) {
  btn.addEventListener("click", function () {
    var code = btn.closest(".install-wrap").querySelector("code");
    var text = code.textContent.trim();
    var done = function (label) {
      var old = btn.textContent;
      btn.textContent = label;
      setTimeout(function () { btn.textContent = old; }, 1500);
    };
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).then(
        function () { done("Copied"); },
        function () { done("Copy failed"); }
      );
    } else {
      done("Select all");
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


def cmd_box(command):
    """A command with a copy button, styled like the package repository."""
    return (
        '<div class="install-wrap">'
        f'<pre class="install"><code>{esc(command)}</code></pre>'
        '<button class="copy-btn" type="button" aria-label="Copy command">'
        "Copy</button>"
        "</div>"
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


def render_card(base_url, flavor, entry, reference):
    name = flavor["name"]
    pairs = releases(entry)
    badge = ""
    if flavor.get("badge"):
        badge = f'<span class="badge">{esc(flavor["badge"])}</span>'

    if not pairs:
        return (
            '<article class="card">'
            f'<div class="card-head"><h3>{esc(flavor["display"])}</h3>{badge}</div>'
            f'<p class="card-desc">{esc(flavor.get("description", ""))}</p>'
            '<p class="card-meta">No build published yet.</p>'
            "</article>"
        )

    date, manifest = pairs[0]
    iso = manifest.get("iso") or {}
    iso_name = iso.get("name") or f"{name}-live-amd64.iso"
    sha256 = iso.get("sha256") or ""
    download = f"{base_url}/latest/{iso_name}"

    age = days_old(date, reference)
    badges = badge
    if age is not None and age > STALE_DAYS:
        badges += f'<span class="badge warn">built {age} days ago</span>'
    badge_html = f"<span>{badges}</span>" if badges else ""

    verify = "\n".join(
        [
            f"curl -LO {download}",
            f"curl -LO {download}.sha256",
            f"curl -LO {download}.sha256.bundle",
            f"curl -LO {base_url}/latest/cosign.pub",
            f"sha256sum -c {iso_name}.sha256",
            "cosign verify-blob --key cosign.pub \\",
            f"  --bundle {iso_name}.sha256.bundle {iso_name}.sha256",
        ]
    )

    sha_cell = (
        f'<p class="card-sha">sha256 '
        f'<code title="{esc(sha256)}">{esc(short_sha(sha256))}</code></p>'
    )

    return f"""<article class="card">
  <div class="card-head">
    <h3>{esc(flavor["display"])}</h3>
    {badge_html}
  </div>
  <p class="card-desc">{esc(flavor.get("description", ""))}</p>
  <p class="card-meta">{esc(date)} · {esc(human_size(iso.get("size")))}</p>
  {sha_cell}
  <a class="button" href="{esc(download)}">Download ISO</a>
  <details>
    <summary>Verify this download</summary>
    {cmd_box(verify)}
  </details>
</article>"""


def render_earlier(base_url, flavors, index):
    rows = []
    for flavor in flavors:
        name = flavor["name"]
        pairs = releases((index.get("flavors") or {}).get(name))
        for date, manifest in pairs[1:]:
            iso = manifest.get("iso") or {}
            iso_name = iso.get("name") or name
            link = iso_url(base_url, date, manifest)
            rows.append(
                "<tr>"
                f'<td data-label="Date">{esc(date)}</td>'
                f'<td data-label="Flavor">{esc(flavor["display"])}</td>'
                f'<td data-label="Size">{esc(human_size(iso.get("size")))}</td>'
                f'<td data-label="Download"><a href="{esc(link)}">'
                f"{esc(iso_name)}</a></td>"
                f'<td class="sha" data-label="SHA256" '
                f'title="{esc(iso.get("sha256", ""))}">'
                f'{esc(short_sha(iso.get("sha256")))}</td>'
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
        body = "<p>No release is published yet.</p>"
    else:
        flavor, manifest = example
        netboot = manifest.get("netboot") or {}
        kernel_args = netboot.get("kernel_args") or "rd.live.image enforcing=0 quiet"
        base = f"{base_url}/latest/netboot/{flavor['name']}"
        kernel = (
            f"kernel {base}/vmlinuz initrd=initrd.img "
            f"root=live:{base}/squashfs.img rd.neednet=1 ip=dhcp {kernel_args}"
        )
        body = f"""<p class="card-desc">
  Example for {esc(flavor["display"])}. The kernel, initrd and squashfs below
  are the same artefacts the ISO boots, extracted at build time. Each release
  also publishes a <code>manifest.json</code> with the exact URLs and hashes.
</p>
{cmd_box(chr(10).join([kernel, f"initrd {base}/initrd.img"]))}"""

    return f"""{body}
<p class="card-desc">
  The <a href="{esc(base_url)}/latest/menu.ipxe">generated iPXE menu</a> lists
  every published flavor and the older releases still inside the retention
  window. Note that <code>root=live:http(s)://</code> downloads the whole
  squashfs into the initramfs (RAM), while <code>root=live:nfs://</code>
  mounts it in place.
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

    names = ", ".join(f["display"] for f in flavors)
    aggregate = "\n".join(
        [
            f"curl -LO {base_url}/latest/SHA256SUMS",
            f"curl -LO {base_url}/latest/SHA256SUMS.bundle",
            f"curl -LO {base_url}/latest/cosign.pub",
            "cosign verify-blob --key cosign.pub \\",
            "  --bundle SHA256SUMS.bundle SHA256SUMS",
            "sha256sum -c SHA256SUMS",
        ]
    )

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
  <style>{CSS}</style>
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

    <section id="verify">
      <h2>Verify every download at once</h2>
      <p class="card-desc">
        <code>SHA256SUMS</code> covers all published flavors ({esc(names)}) and is
        signed as a single file. Download the three ISOs into one directory
        first, then run this there. Each ISO's own checksum is signed too, so a
        single download can be verified on its own from the card above.
      </p>
      {cmd_box(aggregate)}
    </section>

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
