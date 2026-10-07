# Local source build of T3 Code. No AppImage is downloaded, built, or extracted:
# electron-builder's tar.gz target packs the plain unpacked Electron app.

pkgname=t3code
pkgver=0.0.45
pkgrel=1
pkgdesc='Desktop control surface for local coding agents (built from source)'
arch=('x86_64')
url='https://github.com/pingdotgg/t3code'
license=('MIT')
depends=(
  'alsa-lib'
  'at-spi2-core'
  'gtk3'
  'libnotify'
  'libsecret'
  'libxss'
  'libxtst'
  'mesa'
  'nss'
  'util-linux-libs'
  'xdg-utils'
)
makedepends=(
  'cargo'
  'git'
  'nodejs>=24'
  'npm'
  'pkgconf'
  'python'
)
optdepends=('openai-codex: use the system-installed Codex CLI')
provides=("t3code=$pkgver")
conflicts=('t3code-bin' 't3code-nightly-bin')
options=('!debug' '!strip' '!lto')

# makepkg's git+ sources mirror the full history (multiple GB). Keep a shallow
# bare repo in SRCDEST instead and fetch only the release tag; later releases
# only transfer what changed.
_fetch_release() {
  local mirror="${SRCDEST:-$startdir}/$pkgname-shallow.git"
  if [[ ! -d $mirror ]]; then
    git init --bare --quiet "$mirror"
    git -C "$mirror" remote add origin "$url.git"
  fi
  git -C "$mirror" fetch --depth 1 --no-tags origin "+refs/tags/v$pkgver:refs/tags/v$pkgver"
  rm -rf "$srcdir/$pkgname"
  git clone --quiet --shared --branch "v$pkgver" "$mirror" "$srcdir/$pkgname"
}

# Use exactly the pnpm version upstream pins in packageManager, isolated in $srcdir.
_use_upstream_pnpm() {
  local pm _pnpm_prefix="$srcdir/.pnpm-bootstrap"
  pm=$(sed -n 's/.*"packageManager": *"pnpm@\([^"]*\)".*/\1/p' "$srcdir/$pkgname/package.json")
  [[ -n $pm ]] || { echo 'packageManager in package.json is not pnpm' >&2; return 1; }
  if [[ ! -x $_pnpm_prefix/bin/pnpm || $("$_pnpm_prefix/bin/pnpm" --version) != "$pm" ]]; then
    npm install --global --prefix "$_pnpm_prefix" --no-fund --no-audit "pnpm@$pm"
  fi
  export PATH="$_pnpm_prefix/bin:$PATH"
}

prepare() {
  _fetch_release
  cd "$pkgname"
  _use_upstream_pnpm

  # Same install scope as upstream's desktop release job; skips the mobile/Expo tree.
  pnpm install --frozen-lockfile \
    --filter=@t3tools/monorepo \
    --filter=@t3tools/desktop... \
    --filter=t3... \
    --filter=@t3tools/scripts...
}

build() {
  cd "$pkgname"
  _use_upstream_pnpm

  # Cloud/relay sign-in needs the public config upstream CI injects. Export
  # T3CODE_CLERK_PUBLISHABLE_KEY, T3CODE_RELAY_URL, etc. before makepkg to
  # enable it; without them the build is local-only.
  export T3CODE_DESKTOP_OUTPUT_DIR="$srcdir/release"
  rm -rf "$T3CODE_DESKTOP_OUTPUT_DIR"
  pnpm run dist:desktop:artifact \
    --platform linux \
    --target tar.gz \
    --arch x64 \
    --build-version "$pkgver"

  rm -rf "$srcdir/app"
  mkdir -p "$srcdir/app"
  bsdtar -xf "$T3CODE_DESKTOP_OUTPUT_DIR"/*.tar.gz -C "$srcdir/app" --strip-components 1
  [[ -x $srcdir/app/t3code && -f $srcdir/app/chrome-sandbox ]] || {
    echo 'Unpacked app is missing the t3code binary or chrome-sandbox.' >&2
    return 1
  }
}

package() {
  install -d "$pkgdir/opt/$pkgname"
  cp -a --no-preserve=ownership "$srcdir/app/." "$pkgdir/opt/$pkgname/"
  chmod -R u=rwX,go=rX "$pkgdir/opt/$pkgname"
  chmod 4755 "$pkgdir/opt/$pkgname/chrome-sandbox"

  # pacman owns updates; the in-app updater already refuses non-AppImage/.deb
  # installs, this just makes it explicit.
  install -Dm755 /dev/stdin "$pkgdir/usr/bin/t3code" <<EOF
#!/bin/sh
export T3CODE_DISABLE_AUTO_UPDATE=1
exec /opt/$pkgname/t3code "\$@"
EOF

  # Upstream's only Linux icon is 1024px, which hicolor's index.theme doesn't list.
  install -Dm644 "$srcdir/$pkgname/assets/prod/black-universal-1024.png" \
    "$pkgdir/usr/share/pixmaps/t3code.png"

  install -Dm644 /dev/stdin "$pkgdir/usr/share/applications/t3code.desktop" <<'EOF'
[Desktop Entry]
Name=T3 Code
Comment=Desktop control surface for local coding agents
Exec=t3code %U
TryExec=t3code
Terminal=false
Type=Application
Icon=t3code
StartupWMClass=t3code
Categories=Development;
MimeType=x-scheme-handler/t3code;x-scheme-handler/t3code-dev;
EOF

  install -Dm644 "$srcdir/$pkgname/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
