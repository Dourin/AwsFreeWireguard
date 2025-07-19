# Guide de Démarrage Rapide - VPN WireGuard AWS

## Installation Express (5 minutes)

### 1. Prérequis
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y terraform awscli qrencode

# macOS
brew install terraform awscli qrencode
```

### 2. Configuration
```bash
# Cloner le projet (choisissez votre plateforme)
git clone https://github.com/Dourin/AwsFreeWireguard.git
# OU
git clone git@gitlab.com:Muncidor/awsfreewireguard.git

cd AwsFreeWireguard

# Configurer les variables avec exemples concrets
cp .env.example .env
nano .env  # Remplacer par vos vraies clés AWS

# Exemple de format attendu :
# AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
# AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# PROJECT_NAME=mon-vpn-personnel
```

### 3. Déploiement
```bash
# Validation (optionnel)
./validate_config.sh

# Déploiement automatique
./deploy_vpn.sh --force

# Ou déploiement interactif
./deploy_vpn.sh
```

### 4. Configuration Client
```bash
# Les fichiers sont dans terraform/
# - client1.conf (PC/Mac)
# - client1_qr.png (Mobile)
```

## Configuration Mobile
1. Installer WireGuard (PlayStore/AppStore)
2. Scanner le QR code affiché ou importer client1_qr.png
3. Activer la connexion

## Configuration PC/Mac
1. Installer WireGuard : https://www.wireguard.com/install/
2. Importer le fichier `terraform/client1.conf`
3. Activer la connexion

## Gestion des Coûts
```bash
# Arrêter pour économiser (~0.10$/mois au lieu de ~8$/mois)
./stop_vpn.sh

# Redémarrer quand nécessaire
./start_vpn.sh

# Détruire complètement (0$ mais perte de configuration)
./destroy_vpn.sh
```

## Commandes Utiles

**Note** : Pour récupérer l'IP de votre instance : `terraform -chdir=terraform output instance_public_ip`

```bash
# Validation complète
./validate_config.sh

# Statut de l'infrastructure
terraform -chdir=terraform show

# Connexion SSH au serveur (remplacez YOUR_INSTANCE_IP par l'IP de votre instance)
ssh -i terraform/ssh_key.pem ubuntu@YOUR_INSTANCE_IP

# Vérifier WireGuard sur le serveur
ssh -i terraform/ssh_key.pem ubuntu@YOUR_INSTANCE_IP "sudo wg show"
```

## Important
- **Surveillez vos coûts AWS** : https://console.aws.amazon.com/billing/
- **Free Tier** : 750h/mois instance + 15GB transfert sortant
- **IP change** à chaque redémarrage - reconfiguration automatique
- **Détruisez l'infrastructure** quand vous n'en avez plus besoin

## Dépannage Express
```bash
# Problème de connexion AWS
aws sts get-caller-identity

# Problème Terraform
terraform -chdir=terraform validate

# Instance ne répond pas
./validate_config.sh

# Récupération configuration client
ssh -i terraform/ssh_key.pem ubuntu@YOUR_INSTANCE_IP "cat client1.conf"
```

## Monitoring
- **Utilisation AWS** : Console AWS Billing
- **Statut VPN** : `./validate_config.sh`
- **Logs serveur** : `ssh -i terraform/ssh_key.pem ubuntu@YOUR_INSTANCE_IP "sudo journalctl -u wg-quick@wg0"`

---
**PRET !** Votre VPN personnel est opérationnel sur AWS Free Tier.
