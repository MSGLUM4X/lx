# lx

`lx` est un outil permettant de **créer et gérer des utilisateurs de service** sur un serveur Linux.
Ces utilisateurs sont :

* connectés **uniquement via clé SSH**
* dotés d’un **shell restreint**
* conçus pour le **déploiement automatique via GitHub Actions**

`lx` vise un usage **CI/CD sécurisé**, simple et traçable.

---

## Table des matières

* [Prérequis](#prérequis)

  * [Installer GitHub CLI](#installer-github-cli)
  * [Authentifier le serveur auprès de GitHub](#authentifier-le-serveur-auprès-de-github)
* [Création d’un service de déploiement](#création-dun-service-de-déploiement)
* [🔑 Clé de déploiement GitHub](#-clé-de-déploiement-github)
* [Secrets GitHub Actions](#secrets-github-actions)
* [PM2 (optionnel)](#pm2-optionnel)
* [GitHub Actions – Workflow de déploiement automatique](#github-actions--workflow-de-déploiement-automatique)
* [GitHub Actions – Commandes manuelles](#github-actions--commandes-manuelles)
* [Utilisation des commandes via PR](#utilisation-des-commandes-via-pr)
* [Création de commandes pour un service](#création-de-commandes-pour-un-service)
* [Création d’un utilisateur administrateur](#création-dun-utilisateur-administrateur)
* [Suivi et logs](#suivi-et-logs)
* [Désinstallation / nettoyage](#désinstallation--nettoyage)
* [Notes importantes](#notes-importantes)

---

## Prérequis

### Installer GitHub CLI

```bash
sudo apt update
sudo apt install gh
```

### Authentifier le serveur auprès de GitHub

```bash
gh auth login
```

> ⚠️ Cette étape est indispensable pour permettre à `lx` de :
>
> * créer automatiquement des **secrets GitHub Actions**
> * gérer les **clés de déploiement**

---

## Création d’un service de déploiement

```bash
lx-create -u SERVICE_NAME -r git@github.com:USER_GIT/REPO_NAME
```

### Exemple

```bash
lx-create -u api -r git@github.com:my-org/my-repo
```

Cela va :

* créer un utilisateur système `lx-api`
* générer une clé SSH
* préparer les commandes autorisées
* configurer les secrets GitHub Actions

---

## 🔑 Clé de déploiement GitHub

Lors de l’exécution, une clé publique est affichée :

```text
🔑 Paste this in the deploy key of your github repo

ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ...
```

### Actions à effectuer côté GitHub

1. Aller dans **Repository → Settings → Deploy keys**
2. Cliquer sur **Add deploy key**
3. Coller la clé publique
4. Cocher **Allow write access** si nécessaire
5. Valider

Une fois terminé, revenir dans le terminal et appuyer sur **`Y`** pour continuer.

---

## 🔐 Secrets GitHub Actions

`lx` configure automatiquement les secrets suivants :

| Secret           | Description                             |
| ---------------- | --------------------------------------- |
| `LX_SERVER_IP`   | IP publique du serveur                  |
| `LX_SERVER_USER` | Utilisateur de service (`lx-<service>`) |
| `LX_SSH_PORT`    | Port SSH                                |
| `LX_SSH_KEY`     | Clé privée SSH (injectée dans GitHub)   |

---

## PM2 (optionnel)

Si votre service utilise **PM2**, appuyez sur **`Y`** lorsque le script vous demande si vous souhaitez exécuter `pm2 startup`.

Cela permet de relancer automatiquement le service après un redémarrage du serveur.

### Commandes utiles PM2

```bash
sudo -u "$CURRENT_USER" pm2 list
sudo -u "$CURRENT_USER" pm2 status
sudo -u "$CURRENT_USER" pm2 logs
```

---

## GitHub Actions – Workflow de déploiement automatique

Créer le fichier suivant dans votre dépôt :

`.github/workflows/lx.yml`

```yaml
name: LX Remote Command

on:
  push:
    branches:
      - main

jobs:
  execute-commands:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Extraire les commandes du message de commit
        id: extract
        run: |
          COMMIT_MSG=$(git log -1 --pretty=%B)
          echo "$COMMIT_MSG"

          COMMANDS=$(echo "$COMMIT_MSG" | grep -oP '\[cmd:\K[^\]]+' | tr '\n' ' ' | sed 's/ $//')

          if [ -z "$COMMANDS" ]; then
            echo "Aucune commande trouvée, utilisation du défaut"
            COMMANDS="default"
          fi

          echo "commands=$COMMANDS" >> $GITHUB_OUTPUT

      - name: Exécution sur le serveur
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.LX_SERVER_IP }}
          username: ${{ secrets.LX_SERVER_USER }}
          port: ${{ secrets.LX_SSH_PORT }}
          key: ${{ secrets.LX_SSH_KEY }}
          script: ${{ steps.extract.outputs.commands }}
```

---

## GitHub Actions – Commandes manuelles

Ce workflow permet d’exécuter des commandes à la demande.

`.github/workflows/lx-manual.yml`

```yaml
name: LX Remote Command (Manual)

on:
  workflow_dispatch:
    inputs:
      command:
        description: 'Commande à exécuter'
        required: true
        type: choice
        options:
          - default
          - pull
          - deploy
          - custom
      custom_command:
        description: 'Commande personnalisée'
        required: false
        type: string
        default: ''

jobs:
  execute-commands:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Préparer la commande
        id: prepare
        run: |
          if [[ "${{ github.event.inputs.command }}" == "custom" ]]; then
            COMMAND="${{ github.event.inputs.custom_command }}"
          else
            COMMAND="${{ github.event.inputs.command }}"
          fi

          echo "commands=$COMMAND" >> $GITHUB_OUTPUT

      - name: Exécution sur le serveur
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.LX_SERVER_IP }}
          username: ${{ secrets.LX_SERVER_USER }}
          port: ${{ secrets.LX_SSH_PORT }}
          key: ${{ secrets.LX_SSH_KEY }}
          script: ${{ steps.prepare.outputs.commands }}
```

---

## Utilisation des commandes via PR

Lors du **merge d’une pull request**, ajoutez les commandes à exécuter dans le message de merge :

```text
[cmd:pull][cmd:deploy]
```

Les commandes seront exécutées **dans l’ordre**, et l’exécution s’arrête si l’une échoue.

---

## Création de commandes pour un service

1. Se placer dans le dossier `.local/bin` du service (en root)
2. Copier une commande existante :

```bash
cp default NOUVELLE_COMMANDE
chown lx-SERVICE:lx-SERVICE NOUVELLE_COMMANDE
```

3. Modifier `NOUVELLE_COMMANDE`
4. Ajouter son nom dans `.local/command_enabled`

Pour désactiver une commande, il suffit de la retirer de `command_enabled`
(il n’est pas nécessaire de supprimer le fichier).

> Ce dépôt contient un ensemble de **commandes prêtes à l’emploi** :
> [Commands](https://github.com/MSGLUM4X/lx-remote-command)


---

## Création d’un utilisateur administrateur

Il est possible de créer un utilisateur administrateur avec accès au shell restreint.

1. Générer une clé SSH
2. Ajouter cette ligne dans `authorized_keys` du service :

```text
command="SRC_LX-SHELL ADMIN_NAME",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty SSH_KEY
```

3. Ajouter `ADMIN_NAME` dans `.local/logger_enabled`

L’administrateur aura accès à **toutes les commandes autorisées**.

---

## Suivi et logs

### Connexions SSH

```text
.local/shell.log
```

### Logs des commandes

```text
.local/commands.log
```

---

## Désinstallation / nettoyage

### Supprimer lx

```bash
sudo lx-uninstall
```

### Nettoyer la configuration SSH

Éditer :

```bash
sudo nano /etc/ssh/sshd_config
```

* Supprimer l’utilisateur de `AllowUsers`
* Redémarrer SSH :

```bash
sudo systemctl restart ssh
```

### Supprimer le shell lx

```bash
sudo nano /etc/shells
```

Supprimer la ligne correspondant au shell `lx`.

---

## Notes importantes

* Les utilisateurs créés :

  * n’ont **pas de mot de passe**
  * se connectent **uniquement via clé SSH**
  * utilisent un **shell restreint**
* Les clés privées **ne sont jamais stockées sur le serveur**
* `lx` est conçu pour un **déploiement CI/CD sécurisé et traçable**

---

## Author

**Maxime Rouard** — [Website](https://maxime-rouard.fr)

---

## Show Your Support

If this project helped you, give it a ⭐️!

---