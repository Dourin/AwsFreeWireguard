#!/bin/bash

#===============================================================================
# WireGuard QR Code Display Script
# Author: MUNCIULEANU DORIN
# Description: Display QR codes for WireGuard client configurations
# Version: 1.0
# License: MIT
#===============================================================================

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Affichage QR Code WireGuard ===${NC}"
echo ""

# Vérifier si un déploiement existe
if [ ! -f "terraform/ssh_key.pem" ]; then
    echo -e "${RED}Erreur: Aucun VPN déployé trouvé.${NC}"
    echo "Lancez d'abord ./deploy_vpn.sh"
    exit 1
fi

# Récupérer l'IP du serveur
cd terraform
if [ -f "terraform.tfstate" ]; then
    SERVER_IP=$(terraform output -raw server_public_ip 2>/dev/null)
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}Erreur: Impossible de récupérer l'IP du serveur${NC}"
        exit 1
    fi
else
    echo -e "${RED}Erreur: État Terraform non trouvé${NC}"
    exit 1
fi

echo -e "${GREEN}Serveur VPN: $SERVER_IP${NC}"
echo ""

# Récupérer et afficher le QR code
echo -e "${BLUE}QR Code pour configuration mobile WireGuard:${NC}"
echo ""

if ssh -i ssh_key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$SERVER_IP "cat client1_qr.txt" 2>/dev/null; then
    echo ""
    echo -e "${GREEN}Mobile: Scannez ce QR code avec l'application WireGuard sur votre téléphone${NC}"
    echo ""
    echo -e "${BLUE}Instructions:${NC}"
    echo "1. Installez l'application WireGuard sur votre téléphone"
    echo "2. Ouvrez l'application et appuyez sur '+'"
    echo "3. Sélectionnez 'Scanner à partir d'un QR code'"
    echo "4. Scannez le QR code affiché ci-dessus"
    echo "5. Donnez un nom à votre connexion (ex: 'Mon VPN')"
    echo "6. Activez la connexion"
    echo ""
else
    echo -e "${RED}Erreur: Impossible de récupérer le QR code du serveur${NC}"
    echo "Le serveur n'est peut-être pas encore complètement configuré."
    echo "Attendez quelques minutes et relancez ce script."
    exit 1
fi

# Proposer de sauvegarder le QR code
read -p "Voulez-vous sauvegarder le QR code en tant qu'image PNG ? (oui/non): " SAVE_QR
if [[ "$SAVE_QR" =~ ^[oO][uU][iI]$ ]]; then
    if ssh -i ssh_key.pem -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "cat client1_qr.png" > ../client1_qr.png 2>/dev/null; then
        echo -e "${GREEN}QR code sauvegardé dans client1_qr.png${NC}"
    else
        echo -e "${RED}Erreur lors de la sauvegarde du QR code${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}Note: Vous pouvez relancer ce script à tout moment pour réafficher le QR code${NC}"
