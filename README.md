# lx

`lx` est un outil permettant de créer et gérer des **utilisateurs de service** sur un serveur Linux, connectés **uniquement via clé SSH**, et utilisés pour le **déploiement automatique depuis GitHub Actions**.

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

> ⚠️ Cette étape est nécessaire pour créer automatiquement des **secrets GitHub Actions** et gérer les clés de déploiement.

---

## Création d’un service de déploiement

```bash
lx-create -u SERVICE_NAME -r git@github.com:USER_GIT/REPO_NAME
```

### Exemple

```bash
lx-create -u api -r git@github.com:my-org/my-repo
```

---

## 🔑 Clé de déploiement GitHub

Lors de l’exécution, une clé publique est affichée :

```text
🔑 Paste this in the deploy key of your github repo

ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ...
```

👉 **Actions à faire côté GitHub :**

1. Aller dans
   **Repo → Settings → Deploy keys**
2. Cliquer sur **Add deploy key**
3. Coller la clé publique
4. Cocher **Allow write access** si nécessaire
5. Valider

Quand c’est fait, retourner sur le terminal et appuyer sur **`Y`** pour continuer.

---

##  Secrets GitHub Actions

Le script configure automatiquement les secrets suivants :

| Secret           | Description                       |
| ---------------- | --------------------------------- |
| `LX_SERVER_IP`   | IP publique du serveur            |
| `LX_SERVER_USER` | Utilisateur de service (`lx-...`) |
| `LX_SSH_PORT`    | Port SSH                          |
| `LX_SSH_KEY`     | Clé privée SSH                    |

---

##  GitHub Actions – Workflow de déploiement

Ajoutez ce fichier dans votre repo :

`.github/workflows/deploy.yml`

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
  
      - name: Extraire les commandes du merge commit
        id: extract
        run: |
          COMMIT_MSG=$(git log -1 --pretty=%B)
          echo "Message du commit:"
          echo "$COMMIT_MSG"
          
          # Extraire les commandes
          COMMANDS=$(echo "$COMMIT_MSG" | grep -oP '\[cmd:\K[^\]]+' | tr '\n' ' ' |  sed 's/ $//')
          
          if [ -z "$COMMANDS" ]; then
            echo "Aucune commande trouvée, utilisation du défaut"
            COMMANDS="default deploy"
          fi
          
          echo "commands=$COMMANDS" >> $GITHUB_OUTPUT
          echo "Commandes extraites: $COMMANDS"
      - name: Déploiement sur le serveur de production
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.LX_SERVER_IP }}
          username: ${{ secrets.LX_SERVER_USER }}
          port: ${{ secrets.LX_SSH_PORT }}
          key: ${{ secrets.LX_SSH_KEY }}
          script: ${{steps.extract.outputs.commands}}
```

Fork le repo lx-service 
Si le repo change 
git fetch upstream
git merge upstream/main


[cmd:migrate db] [cmd:default deploy]


---

## 🧹 Désinstallation / Nettoyage

Pour supprimer complètement le gestionnaire lx :

### Nettoyer lx 

Utiliser la commande : 

```bash
sudo lx-uninstall
```

### Nettoyer la configuration SSH

Éditer :

```bash
sudo nano /etc/ssh/sshd_config
```

* Supprimer l’utilisateur du `AllowUsers`
* Redémarrer SSH :

```bash
sudo systemctl restart ssh
```

---

### Supprimer le shell personnalisé

Éditer :

```bash
sudo nano /etc/shells
```

Et supprimer la ligne correspondant au shell `lx`.

---

## Notes importantes

* Les utilisateurs créés :

  * n’ont **pas de mot de passe**
  * ne peuvent se connecter **que via clé SSH**
  * ont un shell restreint
* Les clés privées **ne sont jamais stockées sur le serveur**
* `lx` est conçu pour un usage **CI/CD sécurisé**
