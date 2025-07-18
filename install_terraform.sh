#!/bin/bash

#===============================================================================
# Terraform Installation Script
# Author: MUNCIULEANU DORIN
# Description: Automated installation of Terraform on Linux systems
# Version: 1.0
# License: MIT
#===============================================================================

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Installation de Terraform sur Raspberry Pi ===${NC}"
echo ""

# Vérifier si Terraform est déjà installé
if command -v terraform &> /dev/null; then
    CURRENT_VERSION=$(terraform --version | head -n1 | cut -d' ' -f2)
    echo -e "${GREEN}Terraform est déjà installé (version $CURRENT_VERSION)${NC}"
    read -p "Voulez-vous réinstaller la dernière version ? (oui/non): " REINSTALL
    if [[ ! "$REINSTALL" =~ ^[oO][uU][iI]$ ]]; then
        echo -e "${YELLOW}Installation annulée.${NC}"
        exit 0
    fi
fi

# Installer les dépendances
echo -e "${BLUE}Installation des dépendances...${NC}"
sudo apt-get update
sudo apt-get install -y gnupg software-properties-common curl unzip

# Ajouter la clé GPG HashiCorp
echo -e "${BLUE}Ajout de la clé GPG HashiCorp...${NC}"
wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Ajouter le dépôt HashiCorp
echo -e "${BLUE}Ajout du dépôt HashiCorp...${NC}"
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

# Mettre à jour la liste des paquets
sudo apt update

# Installer Terraform
echo -e "${BLUE}Installation de Terraform...${NC}"
sudo apt-get install terraform -y

# Vérifier l'installation
if command -v terraform &> /dev/null; then
    VERSION=$(terraform --version | head -n1)
    echo ""
    echo -e "${GREEN}Terraform installed successfully!${NC}"
    echo -e "${GREEN}Version : $VERSION${NC}"
    echo ""
    echo -e "${BLUE}Prochaines étapes :${NC}"
    echo "1. ./setup_aws.sh   # Configurer AWS CLI"
    echo "2. ./deploy_vpn.sh  # Déployer votre VPN"
else
    echo -e "${RED}Error installing Terraform${NC}"
    exit 1
fi
