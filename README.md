# VPN WireGuard sur AWS Free Tier

Solution complète de déploiement automatisé d'un serveur VPN WireGuard sur AWS Free Tier avec Terraform. Cette solution permet de créer rapidement et facilement un VPN personnel sécurisé sans frais (dans les limites du Free Tier AWS).

## Démarrage Rapide

Consultez le [Guide de Démarrage Rapide](QUICKSTART.md) pour une installation en 5 minutes.

## Fonctionnalités

### Déploiement et Configuration
- **Déploiement automatisé** avec Terraform sur AWS Free Tier
- **Configuration zero-touch** de WireGuard avec clés générées automatiquement
- **Choix de 10 fournisseurs DNS** populaires (Cloudflare, Google, Quad9, etc.)
- **Sélection de région AWS** pour optimiser la latence
- **Mode force** pour les déploiements automatisés sans interaction

### Gestion du Cycle de Vie
- **Scripts start/stop** pour économiser les coûts en arrêtant l'instance quand elle n'est pas utilisée
- **Reconfiguration automatique** lors du redémarrage (nouvelle IP publique)
- **Destruction propre** de l'infrastructure pour éviter les frais

### Sécurité et Confidentialité
- **Variables d'environnement** pour protéger les informations sensibles
- **Configurations client** générées automatiquement avec QR codes
- **Chiffrement WireGuard** moderne et performant
- **Isolation réseau** complète avec VPC dédié

## Prérequis

### Outils Requis
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y terraform awscli qrencode

# macOS
brew install terraform awscli qrencode
```

### Compte AWS
1. Créer un compte AWS (Free Tier eligible)
2. Créer un utilisateur IAM avec les permissions EC2, VPC, et Route53
3. Récupérer les clés d'accès AWS (Access Key ID et Secret Access Key)

## Installation et Configuration

### 1. Cloner et Configurer
```bash
git clone <votre-repo>
cd free_vpn
cp .env.example .env
nano .env  # Éditer avec vos clés AWS
```

### 2. Configuration des Variables (.env)
```bash
# Configuration AWS - REMPLACEZ PAR VOS VRAIES CLÉS
AWS_ACCESS_KEY_ID=your_aws_access_key_id_here
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key_here
AWS_DEFAULT_REGION=eu-west-3
```

### 3. Validation et Déploiement
```bash
# Validation (optionnel)
./validate_config.sh

# Déploiement
./deploy_vpn.sh
```

## Utilisation

### Commandes Principales
```bash
# Déploiement interactif
./deploy_vpn.sh

# Déploiement automatique
./deploy_vpn.sh --force

# Arrêter l'instance (économies)
./stop_vpn.sh

# Redémarrer l'instance
./start_vpn.sh

# Détruire l'infrastructure
./destroy_vpn.sh

# Validation de la configuration
./validate_config.sh
```

## Fournisseurs DNS Disponibles

| Fournisseur | IPs | Avantages |
|-------------|-----|-----------|
| Cloudflare | 1.1.1.1, 1.0.0.1 | Rapide et sécurisé |
| Google | 8.8.8.8, 8.8.4.4 | Fiable et global |
| Quad9 | 9.9.9.9, 149.112.112.112 | Sécurité renforcée |
| OpenDNS | 208.67.222.222, 208.67.220.220 | Filtrage parental |
| AdGuard | 94.140.14.14, 94.140.15.15 | Blocage publicités |
| + 5 autres options | | |

## Régions AWS Supportées

- **eu-west-3** (Paris, France) - Recommandé pour l'Europe
- **eu-central-1** (Francfort, Allemagne)
- **us-east-1** (Virginie, États-Unis)
- **us-west-2** (Oregon, États-Unis)
- **ap-southeast-1** (Singapour)
- **ap-northeast-1** (Tokyo, Japon)

## Configurations Client

Après déploiement, récupérez :
```
terraform/
├── client1.conf          # Configuration WireGuard pour PC/Mac
├── client1_qr.txt        # QR code en texte
├── client1_qr.png        # QR code en image (mobile)
└── ssh_key.pem          # Clé SSH pour accès serveur
```

### Installation sur les Appareils

**Mobile (Android/iOS)**
1. Installer l'application WireGuard officielle
2. Scanner le QR code ou importer client1_qr.png

**PC/Mac/Linux**
1. Installer WireGuard : https://www.wireguard.com/install/
2. Importer le fichier client1.conf

## Surveillance et Coûts

### AWS Free Tier
- **Instance t2.micro** : 750 heures/mois gratuit
- **Transfert sortant** : 15 GB/mois gratuit
- **Stockage EBS** : 30 GB/mois gratuit

### Optimisation des Coûts
- **start/stop** pour usage intermittent (~$0.10/mois vs ~$8/mois)
- **Surveillance** : [AWS Billing Console](https://console.aws.amazon.com/billing/)
- **Destruction** complète quand inutilisé

## Dépannage

### Problèmes Courants
```bash
# Vérifier la configuration
./validate_config.sh

# Tester les clés AWS
aws sts get-caller-identity

# Vérifier Terraform
terraform -chdir=terraform validate

# Connexion SSH au serveur
ssh -i terraform/ssh_key.pem ubuntu@<IP>
```

## Sécurité

### Protection des Données Sensibles
Le `.gitignore` protège automatiquement :
- Clés AWS (`.env`)
- Clés SSH (`*.pem`)
- Configurations WireGuard (`client*.conf`)
- États Terraform (`*.tfstate`)

### Bonnes Pratiques
- Utilisez des mots de passe forts pour AWS
- Activez 2FA sur votre compte AWS
- Changez régulièrement vos clés WireGuard
- Surveillez les logs de connexion

## Architecture

```
Internet Gateway
    ↓
VPC (192.168.100.0/24)
    ↓
Public Subnet
    ↓
EC2 t2.micro (Ubuntu 22.04)
    ↓
WireGuard (port 51820/UDP)
```

## Support

- **Documentation complète** : Ce README
- **Guide rapide** : [QUICKSTART.md](QUICKSTART.md)
- **Validation** : `./validate_config.sh`
- **Problèmes connus** : L'IP change à chaque redémarrage

## Licence

Ce projet est sous licence MIT. Consultez le fichier [LICENSE](LICENSE) pour plus de détails.

---

⚠️ **IMPORTANT** : N'oubliez pas d'exécuter `./destroy_vpn.sh` quand vous avez terminé pour éviter les frais AWS !
