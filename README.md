# rukav-swiss.ch

Website of **RuKAV** — the Russian-speaking Cultural and Academic Association
(*Russischsprechender Kultureller und Akademischer Verein*) in Zurich, Switzerland.

Built with [Hugo](https://gohugo.io/), using the
[Ananke](https://github.com/theNewDynamic/gohugo-theme-ananke) theme (MIT) as a
git submodule, and served by Caddy on a VPS.

Live site: <https://rukav-swiss.ch/>

## Requirements

- Hugo **extended**, version `0.164.0` (the version CI and Docker build with —
  see [.github/workflows/hugo.yaml](.github/workflows/hugo.yaml)), **or**
  [Docker](https://docs.docker.com/get-docker/) and Docker Compose

No Node.js toolchain is needed: CSS is assembled by Hugo from the theme's own
`assets/ananke/css/`.

## Updating the theme

`themes/ananke` is a git submodule. To pick up a new Ananke release:

```bash
cd themes/ananke
git fetch --tags
git checkout vX.Y.Z
cd ../..
git add themes/ananke
```

Then rebuild and check that nothing in `layouts/` (our overrides) has drifted
from the new upstream templates — [Ananke's release notes](https://github.com/theNewDynamic/gohugo-theme-ananke/releases)
list breaking changes.

## Local development

### Hugo only

```bash
git clone --recurse-submodules git@github.com:rukav-swiss/website-rukav.git
cd website-rukav
hugo server
```

Then open <http://localhost:1313/>.

To produce a production build into `public/`:

```bash
hugo --gc --minify
```

### Docker (Hugo behind Caddy)

Needs [Docker](https://docs.docker.com/get-docker/) and Docker Compose.

```bash
docker compose up --build
```

Open <http://localhost:8080/>. Caddy reverse-proxies to Hugo so local URLs
match the production layout. Live rebuild on file changes (refresh the browser).

Stop with `Ctrl+C`, or `docker compose down`.

## Layout

| Path | Contents |
|---|---|
| `content/en/`, `content/ru/` | Page content, one directory per language |
| `config.toml` | Site config: languages, menus, params |
| `layouts/` | Templates that override the theme; only files that differ from [Ananke](https://github.com/theNewDynamic/gohugo-theme-ananke) live here — everything else comes from `themes/ananke` |
| `assets/images/` | Photos, processed by Hugo (resized to WebP + `srcset`) |
| `static/` | Files served verbatim: logos, favicon, PDFs |
| `i18n/` | UI string translations |
| `docker-compose.yml` | Caddy + Hugo (local: port 8080) |
| `docker-compose.prod.yml` | Production overlay: ports 80/443, Let's Encrypt |
| `deploy/Caddyfile` | Reverse proxy for local Docker |
| `deploy/Caddyfile.prod` | Reverse proxy for `rukav-swiss.ch` |

`static/images/gohugo-default-sample-hero-image.jpg` is an intentional 0-byte
stub: Ananke ships an unused sample image at that path, and this project file
shadows it so the real 280 KB original is not published. Unreferenced either
way — safe to ignore.

## Adding content

### A new event

Create `content/en/events/YYYY-MM-DD_slug.md` (and the Russian counterpart in
`content/ru/events/`):

```yaml
---
date: 2026-09-01T00:00:00+02:00
title: "Event title"
description: "One sentence — used for SEO and link previews."
featured_image: "images/your-photo.jpg"
tags: []
---
```

Always fill in `description`: it becomes the page's meta description and the
text shown when the link is shared.

### Images

Put photos in **`assets/images/`**, not `static/`. Hugo resizes them to WebP at
several widths and emits a `srcset`, so a 6 MB camera JPEG is served as ~100 KB.
Reference them from Markdown with a normal image link and meaningful alt text:

```markdown
![Description of the photo](images/your-photo.jpg)
```

For several event photos on one page, wrap them so they sit in a row
instead of stacking full-width. Set `content_image_widths` /
`content_image_sizes` in front matter so the browser fetches thumbnails:

```markdown
{{< gallery class="event-photos" >}}
![Friday game night](images/2026-01-30_Board-games.jpg)
{{< /gallery >}}
```

Files in `static/images/` (the logos) are served untouched.

If an image must **not** be recompressed — a QR code, or anything where
artifacts would matter — add its path to `params.verbatim_images` in
`config.toml`. It is then published byte-for-byte, but still gets `width` and
`height` so it does not shift the layout. The bank QR code is handled this way:
it has to stay scannable, and Hugo cannot produce truly lossless WebP.

### Link previews

`featured_image` doubles as the Open Graph / Twitter card image, cropped to
1200x630. Pages without one fall back to `params.social_image` in `config.toml`.

## Deployment

The site is **not** on GitHub Pages. Pushing `main` runs
[.github/workflows/hugo.yaml](.github/workflows/hugo.yaml): Hugo build check,
then SSH to the VPS, `git pull --ff-only`, submodule update, and
`docker compose ... up -d --build`. Pull requests only build.

GitHub Actions talks to the VPS with a **second** SSH key (Actions → VPS).
The VPS talks to GitHub with a **deploy key** (VPS → GitHub). They are not
the same key.

### 1. GitHub: private repo, Pages off

1. Repository → **Settings → General → Danger Zone → Change repository
   visibility** → Private (so photos and unpublished work are not public).
2. **Settings → Pages**: Source **None**. Remove any custom domain listed
   there (`rukav-swiss.ch`). Pages is unused after this; leaving it on
   fights DNS once the domain points at the VPS.
3. Actions stay enabled (Settings → Actions → Allow). Private-repo minutes
   on GitHub Free are enough for this workflow.

No GitHub Pages environment, no `pages: write` token, no `CNAME` file.

### 2. DNS

In the domain registrar, **replace** GitHub Pages records with the VPS:

| Type | Name | Value |
|---|---|---|
| A | `@` | VPS IPv4 |
| AAAA | `@` | VPS IPv6 (if it has one) |
| CNAME | `www` | `rukav-swiss.ch` (optional; Caddy redirects www → apex) |

Remove the four GitHub Pages A records (`185.199.108.153` …
`185.199.111.153`) and `AAAA` `2606:50c0:8000::` … `8003::`.

Switch DNS **after** the VPS stack is up and Caddy can answer on 80/443,
or there will be a gap while TLS is issued. Until then the old Pages site
can keep serving.

### 3. VPS: clone a private repo (deploy key)

GitHub deploy keys are **one key per repo**. If this machine already has a
deploy key for another private repo (for example antmaxi-website), use a
**named Host** so SSH does not send the wrong key to `github.com`.

On the VPS:

```bash
ssh-keygen -t ed25519 -C "vps-rukav-website" -f ~/.ssh/rukav-github -N ""
cat ~/.ssh/rukav-github.pub
```

GitHub → `rukav-swiss/website-rukav` → **Settings → Deploy keys → Add
deploy key**. Paste the public key. Leave **Allow write access** unchecked.

`~/.ssh/config` on the VPS:

```
Host github.com-rukav
  HostName github.com
  User git
  IdentityFile ~/.ssh/rukav-github
  IdentitiesOnly yes
```

```bash
git clone --recurse-submodules git@github.com-rukav:rukav-swiss/website-rukav.git /opt/website-rukav
cd /opt/website-rukav
```

### 4. VPS: first run

Needs Docker Compose. Open 80 and 443 on the VPS firewall **and** `ufw` if
it is enabled:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

That binds **80 and 443**, uses `deploy/Caddyfile.prod` (`rukav-swiss.ch` +
Let's Encrypt), and runs Hugo with `--environment production`.

Check from the VPS:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
curl -sSI --connect-timeout 3 http://127.0.0.1/
ss -tlnp | grep -E ':80|:443|:8080'
```

`http://rukav-swiss.ch` should redirect to HTTPS once DNS points here.
Caddy issues the certificate automatically.

**Same VPS as another site that already binds 80/443** (for example
antmaxi.site): two Caddy containers cannot both own those ports. Add
`rukav-swiss.ch` as another site block on that existing Caddy instead of
starting this stack's Caddy, or use a separate machine.

### 5. GitHub Actions → VPS (push to deploy)

This is a **second** SSH key, not the repo deploy key.

1. Create the key (no passphrase), on your laptop:

```bash
ssh-keygen -t ed25519 -C "github-actions-rukav-site" -f github-actions-vps -N ""
```

2. On the VPS, append `github-actions-vps.pub` to that user's
   `~/.ssh/authorized_keys` (`chmod 600`). The user must be able to
   `git pull` in the clone and run `docker compose`. If this is the same
   VPS user you already use for antmaxi-website, you can reuse that
   Actions key and skip this step.

3. GitHub → `rukav-swiss/website-rukav` → **Settings → Secrets and
   variables → Actions**. Add:

| Secret | Value |
|---|---|
| `VPS_HOST` | `rukav-swiss.ch` (or the VPS IPv4) |
| `VPS_USER` | SSH username on the VPS |
| `VPS_SSH_KEY` | Full private key (`github-actions-vps`), including `BEGIN`/`END` lines |
| `VPS_APP_DIR` | Absolute path of the clone, e.g. `/opt/website-rukav` |
| `VPS_PORT` | `22` unless you changed sshd |
| `VPS_SSH_FINGERPRINT` | Host key SHA256 (optional but recommended) |

Fingerprint from your laptop:

```bash
ssh-keyscan -t ed25519 rukav-swiss.ch 2>/dev/null | ssh-keygen -lf -
```

Use the `SHA256:...` value (the action wants that fingerprint). If DNS does
not point at the VPS yet, scan the IPv4 instead.

4. Actions → **Build and deploy** → Run workflow, or push a commit to
   `main`.

After that, every push to `main` pulls on the VPS and recreates the
containers. Do not push until the secrets exist, or the deploy job fails
(the Hugo build check still runs).

## Licence

Theme code derived from Ananke is MIT licensed — see [LICENSE.md](LICENSE.md).
Site content and photographs belong to the RuKAV association.
