#!/usr/bin/bash
umask 077
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SRC_DIR/lx.conf"
LX_DIR="/etc/lx"
CONFIG_DEST="$LX_DIR/lx.conf"
CMD_INSTALLED="$LX_DIR/cmd_installed"
CMD_DIR="$SRC_DIR/cmd/bin"
SKEL_SRC="$SRC_DIR/skel-lx"
SKEL_DEST="$LX_DIR/skel-lx"

if [[ -d "$LX_DIR" ]]; then
  read -rp "Update lx ? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Installation Cancelled" 
    exit 0
  fi
fi

if [[ ! -d "$SKEL_SRC" ]]; then
  echo "Dossier source introuvable : $SKEL_SRC"
  exit 1
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Dossier source introuvable : $SRC_DIR" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then 
  echo "Config manquante : $CONFIG_FILE" >&2
  exit 1
fi

while IFS='=' read -r key value; do
  # Ignorer lignes vides ou commentaires
  [[ -z "$key" || "$key" =~ ^# ]] && continue

  case "$key" in
    CMD_DEST)
      CMD_DEST="$value"
      ;;
  esac
done < "$CONFIG_FILE"

echo "Importation du fichier de configuration terminée"

sudo mkdir -p "$LX_DIR"
sudo install -m 644 "$CONFIG_FILE" "$CONFIG_DEST"
sudo touch "$CMD_INSTALLED"
sudo chmod 644 "$CMD_INSTALLED"

echo "Installation du $LX_DIR réussi"

for file in "$CMD_DIR"/*; do
  [[ -f "$file" ]] || continue

  cmd_name="$(basename "$file")"
  echo "Installation de $cmd_name"

  sudo install -m 755 "$file" "$CMD_DEST/$cmd_name"
  echo "$cmd_name" | sudo tee -a "$CMD_INSTALLED" >/dev/null
done

sudo cp -r "$SKEL_SRC" "$SKEL_DEST"

# Fixer les permissions : root:root et 755 pour les dossiers, 644 pour les fichiers
sudo find "$SKEL_DEST" -type d -exec chmod 755 {} \;
sudo find "$SKEL_DEST" -type f -exec chmod 644 {} \;

if [[ -d "$SKEL_DEST/.local/bin" ]]; then
  sudo find "$SKEL_DEST/.local/bin" -type f -exec chmod 755 {} \;
fi

sudo chown -R root:root "$SKEL_DEST"

echo "Installation terminée"
exit 0


