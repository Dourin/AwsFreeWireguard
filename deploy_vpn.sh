#!/bin/bash

#===============================================================================
# VPN WireGuard Deployment Script for AWS Free Tier
# Author: MUNCIULEANU DORIN
# Description: Automated deployment of WireGuard VPN server on AWS Free Tier
# Version: 1.0
# License: MIT
#===============================================================================

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Charger les variables d'environnement
if [ -f .env ]; then
    set -a
    source .env
    set +a
    
    # Debug: vérifier que les variables sont chargées
    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        echo -e "${RED}Erreur: AWS_ACCESS_KEY_ID non défini dans .env${NC}"
        exit 1
    fi
else
    echo -e "${RED}Erreur: Fichier .env non trouvé.${NC}"
    echo "Copiez .env.example vers .env et configurez vos variables AWS"
    exit 1
fi

echo -e "${BLUE}=== VPN WireGuard Deployment on AWS Free Tier ===${NC}"
echo ""

# Vérifier si Terraform est installé
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Erreur: Terraform n'est pas installé.${NC}"
    echo "Veuillez installer Terraform"
    exit 1
fi

# Vérifier si AWS CLI est installé
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Erreur: AWS CLI n'est pas installé.${NC}"
    echo "Veuillez installer AWS CLI"
    exit 1
fi

# Vérifier si AWS CLI est configuré avec les variables d'environnement
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Erreur: AWS CLI n'est pas configuré correctement.${NC}"
    echo "Vérifiez vos variables AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY dans le fichier .env"
    exit 1
fi

# Vérifier si mode force est activé
if [[ "$1" == "--force" ]]; then
    AWS_REGION="${AWS_DEFAULT_REGION:-eu-west-3}"
    DNS_SERVERS="1.1.1.1, 1.0.0.1"  # Cloudflare par défaut
    echo -e "${GREEN}Mode force activé - Région: $AWS_REGION${NC}"
    echo -e "${GREEN}DNS par défaut: Cloudflare (1.1.1.1, 1.0.0.1)${NC}"
else
    # List of popular AWS regions
    echo -e "${YELLOW}Available AWS regions:${NC}"
    echo "1. eu-west-3 (Paris, France)"
    echo "2. eu-central-1 (Francfort, Allemagne)"
    echo "3. us-east-1 (Virginie, États-Unis)"
    echo "4. us-west-2 (Oregon, États-Unis)"
    echo "5. ap-southeast-1 (Singapour)"
    echo "6. ap-northeast-1 (Tokyo, Japon)"
    echo "7. Autre (saisie manuelle)"
    echo ""

    read -p "Choose your region (1-7): " REGION_CHOICE

    case $REGION_CHOICE in
        1) AWS_REGION="eu-west-3" ;;
        2) AWS_REGION="eu-central-1" ;;
        3) AWS_REGION="us-east-1" ;;
        4) AWS_REGION="us-west-2" ;;
        5) AWS_REGION="ap-southeast-1" ;;
        6) AWS_REGION="ap-northeast-1" ;;
        7) 
            read -p "Enter AWS region code: " AWS_REGION
            ;;
        *)
            echo -e "${RED}Invalid choice. Using ${AWS_DEFAULT_REGION:-eu-west-3} by default.${NC}"
            AWS_REGION="${AWS_DEFAULT_REGION:-eu-west-3}"
            ;;
    esac

    # DNS Configuration
    echo ""
    echo -e "${YELLOW}Available DNS servers:${NC}"
    echo "1. Cloudflare (1.1.1.1, 1.0.0.1) - Rapide et sécurisé"
    echo "2. Google (8.8.8.8, 8.8.4.4) - Fiable et global"
    echo "3. Quad9 (9.9.9.9, 149.112.112.112) - Sécurité renforcée"
    echo "4. OpenDNS (208.67.222.222, 208.67.220.220) - Filtrage parental"
    echo "5. AdGuard (94.140.14.14, 94.140.15.15) - Blocage publicités"
    echo "6. DNS.Watch (84.200.69.80, 84.200.70.40) - Neutre et privé"
    echo "7. Comodo (8.26.56.26, 8.20.247.20) - Protection malware"
    echo "8. Level3 (4.2.2.1, 4.2.2.2) - Infrastructure Tier 1"
    echo "9. Yandex (77.88.8.8, 77.88.8.1) - Basé en Russie"
    echo "10. Custom (saisie manuelle)"
    echo ""

    read -p "Choose your DNS servers (1-10): " DNS_CHOICE

    case $DNS_CHOICE in
        1) DNS_SERVERS="1.1.1.1, 1.0.0.1" ;;
        2) DNS_SERVERS="8.8.8.8, 8.8.4.4" ;;
        3) DNS_SERVERS="9.9.9.9, 149.112.112.112" ;;
        4) DNS_SERVERS="208.67.222.222, 208.67.220.220" ;;
        5) DNS_SERVERS="94.140.14.14, 94.140.15.15" ;;
        6) DNS_SERVERS="84.200.69.80, 84.200.70.40" ;;
        7) DNS_SERVERS="8.26.56.26, 8.20.247.20" ;;
        8) DNS_SERVERS="4.2.2.1, 4.2.2.2" ;;
        9) DNS_SERVERS="77.88.8.8, 77.88.8.1" ;;
        10) 
            read -p "Enter DNS servers (format: 1.1.1.1, 8.8.8.8): " DNS_SERVERS
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Using Cloudflare by default.${NC}"
            DNS_SERVERS="1.1.1.1, 1.0.0.1"
            ;;
    esac
fi

echo -e "${GREEN}Selected region: $AWS_REGION${NC}"
echo -e "${GREEN}Selected DNS: $DNS_SERVERS${NC}"
echo ""

# Navigate to terraform directory
cd "$(dirname "$0")/terraform"

# Initialize Terraform
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}Erreur lors de l'initialisation de Terraform${NC}"
    exit 1
fi

# Valider la configuration
echo -e "${BLUE}Validation de la configuration...${NC}"
terraform validate

if [ $? -ne 0 ]; then
    echo -e "${RED}Erreur de validation de la configuration Terraform${NC}"
    exit 1
fi

# Planifier le déploiement
echo -e "${BLUE}Planification du déploiement...${NC}"
terraform plan -var="aws_region=${AWS_REGION}" -var="dns_servers=${DNS_SERVERS}" -var="project_name=${PROJECT_NAME}" -var="vpc_cidr=${VPN_SUBNET}"

# Demander confirmation sauf en mode force
if [[ "$1" != "--force" ]]; then
    echo ""
    read -p "Voulez-vous procéder au déploiement ? (oui/non): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[oO][uU][iI]$ ]]; then
        echo -e "${YELLOW}Déploiement annulé.${NC}"
        exit 0
    fi
fi

# Appliquer la configuration Terraform
echo -e "${BLUE}Lancement du déploiement...${NC}"
terraform apply -var="aws_region=${AWS_REGION}" -var="dns_servers=${DNS_SERVERS}" -var="project_name=${PROJECT_NAME}" -var="vpc_cidr=${VPN_SUBNET}" -auto-approve

if [ $? -ne 0 ]; then
    echo -e "${RED}Erreur lors du déploiement${NC}"
    exit 1
fi

# Récupérer les informations importantes
echo ""
echo -e "${GREEN}=== Déploiement terminé avec succès ! ===${NC}"
echo ""

SERVER_IP=$(terraform output -raw server_public_ip)
SERVER_REGION=$(terraform output -raw server_region)
SSH_COMMAND=$(terraform output -raw ssh_connection_command)

echo -e "${BLUE}Informations du serveur:${NC}"
echo "IP publique: $SERVER_IP"
echo "Région: $SERVER_REGION"
echo ""

# Sauvegarder la clé SSH
echo -e "${BLUE}Sauvegarde de la clé SSH...${NC}"
terraform output -raw ssh_private_key > ssh_key.pem
chmod 600 ssh_key.pem

# Attendre que le serveur soit complètement configuré
echo -e "${YELLOW}Attente de la configuration complète du serveur (cela peut prendre 3-4 minutes)...${NC}"
sleep 45

# Tenter de récupérer les configurations client avec plus de patience
echo -e "${BLUE}Récupération des configurations client...${NC}"
for i in {1..20}; do
    if ssh -i ssh_key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$SERVER_IP "test -f setup_complete" &>/dev/null; then
        echo -e "${GREEN}Serveur prêt !${NC}"
        break
    fi
    if [ $i -eq 10 ]; then
        echo -e "${YELLOW}Configuration prend plus de temps, vérification de l'état...${NC}"
        ssh -i ssh_key.pem -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "tail -5 /var/log/cloud-init-output.log" 2>/dev/null || echo "Logs non disponibles"
    fi
    echo "Tentative $i/20... (Attente configuration automatique)"
    sleep 15
done

# Vérifier et corriger la configuration si nécessaire
echo -e "${BLUE}Vérification et optimisation de la configuration...${NC}"
ssh -i ssh_key.pem -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "export DNS_SERVERS=\"${DNS_SERVERS}\"; $(cat << 'REMOTE_SCRIPT'
# Vérifier l'\''état du service
SERVICE_ACTIVE=$(sudo systemctl is-active wg-quick@wg0 2>/dev/null)
if [ "$SERVICE_ACTIVE" != "active" ]; then
    echo "Service WireGuard inactif, correction en cours..."
    
    # Detecter l'\''interface réseau principale
    MAIN_INTERFACE=$(ip route | grep default | awk "{print \$5}" | head -n1)
    echo "Interface détectée: $MAIN_INTERFACE"
    
    # Arrêter le service et nettoyer
    sudo systemctl stop wg-quick@wg0 >/dev/null 2>&1
    sudo ip link delete wg0 >/dev/null 2>&1
    
    # Nettoyer les règles iptables
    sudo iptables -F FORWARD >/dev/null 2>&1
    sudo iptables -t nat -F POSTROUTING >/dev/null 2>&1
    
    # Recréer la configuration proprement
    cd /home/ubuntu
    if [ -f server_private.key ]; then
        SERVER_PRIVATE_KEY=$(cat server_private.key)
        SERVER_PUBLIC_KEY=$(cat server_public.key)
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "'$SERVER_IP'")
        
        # Créer une configuration WireGuard simple et fonctionnelle avec sous-réseau dédié
        sudo tee /etc/wireguard/wg0.conf > /dev/null << WGCONF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 192.168.100.1/24
ListenPort = 51820
PostUp = iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o $MAIN_INTERFACE -j MASQUERADE; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; ip route del 192.168.100.0/24 via $(ip route | grep default | awk '"'"'{print $3}'"'"') dev $MAIN_INTERFACE 2>/dev/null || true
PostDown = iptables -t nat -D POSTROUTING -s 192.168.100.0/24 -o $MAIN_INTERFACE -j MASQUERADE; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

WGCONF

        # Ajouter les peers clients avec sous-réseau corrigé
        for i in {1..5}; do
            if [ -f client${i}_public.key ]; then
                CLIENT_PUBLIC_KEY=$(cat client${i}_public.key)
                sudo tee -a /etc/wireguard/wg0.conf > /dev/null << WGPEER

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 192.168.100.$((i+1))/32

WGPEER
            fi
        done
        
        # Créer les configurations clients si elles n'\''existent pas avec sous-réseau corrigé
        for i in {1..5}; do
            if [ ! -f client${i}.conf ] && [ -f client${i}_private.key ]; then
                CLIENT_PRIVATE_KEY=$(cat client${i}_private.key)
                CLIENT_IP="192.168.100.$((i+1))"
                
                tee client${i}.conf > /dev/null << CLIENTCONF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = $DNS_SERVERS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLIENTCONF
                
                # Créer le QR code
                qrencode -t ansiutf8 < client${i}.conf > client${i}_qr.txt 2>/dev/null || echo "QR failed for client $i"
                qrencode -t png -o client${i}_qr.png < client${i}.conf 2>/dev/null || echo "PNG QR failed for client $i"
            elif [ -f client${i}.conf ]; then
                # Vérifier si la configuration existante a un endpoint valide ou utilise l'\''ancien sous-réseau
                if grep -q "Endpoint = :51820\|Endpoint = PLACEHOLDER_IP:51820\|Address = 10\.0\.0\." client${i}.conf; then
                    echo "Correction de l'\''endpoint et sous-réseau pour client${i}..."
                    CLIENT_PRIVATE_KEY=$(cat client${i}_private.key)
                    CLIENT_IP="192.168.100.$((i+1))"
                    
                    tee client${i}.conf > /dev/null << CLIENTCONF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = $DNS_SERVERS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLIENTCONF
                    
                    # Regénérer le QR code
                    qrencode -t ansiutf8 < client${i}.conf > client${i}_qr.txt 2>/dev/null || echo "QR failed for client $i"
                    qrencode -t png -o client${i}_qr.png < client${i}.conf 2>/dev/null || echo "PNG QR failed for client $i"
                fi
            fi
        done
        
        # Permissions et démarrage
        sudo chmod 600 /etc/wireguard/wg0.conf
        sudo systemctl start wg-quick@wg0
        echo "Configuration corrigée et service redémarré"
    else
        echo "Clés non trouvées, configuration manuelle requise"
    fi
else
    echo "Service WireGuard déjà actif"
    
    # Nettoyer les routes conflictuelles même si le service est actif
    echo "Nettoyage des routes conflictuelles..."
    sudo ip route del 10.0.0.2 via $(ip route | grep default | awk "{print \$3}") dev $(ip route | grep default | awk "{print \$5}") 2>/dev/null || true
    sudo ip route del 10.0.0.0/24 via $(ip route | grep default | awk "{print \$3}") dev $(ip route | grep default | awk "{print \$5}") 2>/dev/null || true
fi
REMOTE_SCRIPT
)"

# Récupérer la configuration client principale
echo -e "${BLUE}Récupération de la configuration WireGuard...${NC}"

# Attendre un peu plus pour que les fichiers soient créés
sleep 5

# Vérifier d'abord si les fichiers existent sur le serveur
echo "Vérification des fichiers de configuration..."
FILE_CHECK=$(ssh -i ssh_key.pem -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "ls -la client*.conf client*_qr.txt 2>/dev/null | wc -l" 2>/dev/null || echo "0")

if [ "$FILE_CHECK" -gt "0" ]; then
    # Récupérer la configuration client
    if ssh -i ssh_key.pem -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "cat client1.conf" > client1.conf 2>/dev/null; then
        echo -e "${GREEN}Configuration client sauvegardée dans client1.conf${NC}"
        
        # Récupérer et afficher le QR code
        echo ""
        echo -e "${BLUE}QR Code pour configuration mobile:${NC}"
        if ssh -i ssh_key.pem -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "cat client1_qr.txt" 2>/dev/null; then
            echo ""
            echo -e "${GREEN}Scannez ce QR code avec votre application WireGuard mobile${NC}"
        else
            echo -e "${YELLOW}QR code non disponible, utilisation de la configuration textuelle${NC}"
        fi
        
        # Sauvegarder le QR code en tant qu'image
        if ssh -i ssh_key.pem -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "test -f client1_qr.png" 2>/dev/null; then
            ssh -i ssh_key.pem -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "cat client1_qr.png" > client1_qr.png 2>/dev/null
            echo -e "${GREEN}QR code image sauvegardé dans client1_qr.png${NC}"
        fi
    else
        echo -e "${YELLOW}Configuration client non disponible, récupération manuelle nécessaire${NC}"
    fi
else
    echo -e "${YELLOW}Fichiers de configuration non trouvés, vérification manuelle nécessaire${NC}"
    echo "Connexion SSH pour diagnostic:"
    echo "$SSH_COMMAND"
fi

echo ""
echo -e "${GREEN}=== Instructions d'utilisation ===${NC}"
echo ""
echo -e "${BLUE}1. Configuration WireGuard:${NC}"
if [ -f "client1.conf" ]; then
    echo "   Mobile: Scan the QR code displayed above"
    echo "   PC: Your client configuration is in: $(pwd)/client1.conf"
    echo "   QR code image: $(pwd)/client1_qr.png"
    echo "   Copy these files to your client devices"
else
    echo "   Connectez-vous au serveur pour récupérer la configuration:"
    echo "   cd $(dirname "$0")/terraform && $SSH_COMMAND"
    echo "   Puis récupérez les fichiers:"
    echo "   - Configuration: cat client1.conf"
    echo "   - QR code: cat client1_qr.txt"
fi
echo ""
echo -e "${BLUE}2. Connexion SSH (pour dépannage):${NC}"
echo "   cd $(dirname "$0")/terraform && $SSH_COMMAND"
echo ""
echo -e "${BLUE}3. Vérifier le statut du VPN:${NC}"
echo "   cd $(dirname "$0")/terraform && ssh -i ssh_key.pem ubuntu@$SERVER_IP './vpn_status.sh'"
echo ""
echo -e "${RED}4. IMPORTANT - Destruction:${NC}"
echo -e "${RED}   N'oubliez pas d'exécuter ./destroy_vpn.sh quand vous avez terminé !${NC}"
echo -e "${RED}   Ceci est crucial pour éviter les frais AWS.${NC}"
echo ""
echo -e "${YELLOW}5. Surveillance:${NC}"
echo "   Surveillez votre usage AWS sur: https://console.aws.amazon.com/billing/"
echo "   Free Tier: 750h/mois instance t2.micro + 15GB transfert sortant"
echo ""

# Créer un fichier de résumé
cat > deployment_info.txt << EOF
=== Informations de déploiement VPN ===
Date: $(date)
Région: $SERVER_REGION
IP serveur: $SERVER_IP
Connexion SSH: $SSH_COMMAND

Fichiers importants:
- ssh_key.pem: Clé privée SSH
- client1.conf: Configuration WireGuard client
- deployment_info.txt: Ce fichier

Pour détruire: ./destroy_vpn.sh
EOF

echo -e "${GREEN}Informations sauvegardées dans deployment_info.txt${NC}"
