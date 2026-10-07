#!/usr/bin/env bash
# One-time setup: create the local repo, build the first package, register the
# repo with pacman, and enable the daily rebuild timer. Safe to re-run.
set -euo pipefail

PKG_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
REPO_NAME=t3code-local
REPO_DIR=${T3CODE_REPO_DIR:-/srv/t3code-repo}
OLD_REPO_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/t3code-repo
UNIT_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user

chmod +x "$PKG_DIR/t3code-repo-update"

if [[ ! -d $REPO_DIR ]]; then
  echo "Creating $REPO_DIR (needs sudo)"
  sudo install -d -m755 -o "$(id -un)" -g "$(id -gn)" "$REPO_DIR"
fi

if [[ -d $OLD_REPO_DIR && $OLD_REPO_DIR != "$REPO_DIR" ]]; then
  echo "Moving existing repo from $OLD_REPO_DIR to $REPO_DIR"
  cp -a "$OLD_REPO_DIR/." "$REPO_DIR/"
  rm -rf "$OLD_REPO_DIR"
fi

if [[ ! -f $REPO_DIR/$REPO_NAME.db.tar.gz ]]; then
  "$PKG_DIR/t3code-repo-update" --force
fi

if ! grep -q "^\[$REPO_NAME\]" /etc/pacman.conf; then
  echo "Adding [$REPO_NAME] to /etc/pacman.conf (needs sudo)"
  printf '\n[%s]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$REPO_NAME" "$REPO_DIR" |
    sudo tee -a /etc/pacman.conf >/dev/null
elif ! sed -n "/^\[$REPO_NAME\]/,/^\[/p" /etc/pacman.conf | grep -qx "Server = file://$REPO_DIR"; then
  echo "Pointing [$REPO_NAME] at $REPO_DIR in /etc/pacman.conf (needs sudo)"
  sudo sed -i "/^\[$REPO_NAME\]/,/^\[/ s|^Server = .*|Server = file://$REPO_DIR|" /etc/pacman.conf
fi

mkdir -p "$UNIT_DIR"
sed "s|@PKG_DIR@|$PKG_DIR|g" "$PKG_DIR/systemd/t3code-repo-update.service" \
  >"$UNIT_DIR/t3code-repo-update.service"
install -m644 "$PKG_DIR/systemd/t3code-repo-update.timer" "$UNIT_DIR/"
systemctl --user daemon-reload
systemctl --user enable --now t3code-repo-update.timer

cat <<EOF

Done. Install it with a full upgrade (not -Sy alone):

  sudo pacman -Syu t3code

From now on new releases are built daily and arrive through arch-update.
EOF
