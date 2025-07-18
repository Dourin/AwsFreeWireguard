#!/bin/bash

#===============================================================================
# AWS Configuration Setup Script
# Author: MUNCIULEANU DORIN
# Description: Configure AWS CLI credentials for VPN deployment
# Version: 1.0
# License: MIT
#===============================================================================

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Configuration d'AWS CLI pour le projet VPN ===${NC}"
echo ""

# Vérifier si AWS CLI est installé
if ! command -v aws &> /dev/null; then
    echo -e "${YELLOW}AWS CLI n'est pas installé. Installation...${NC}"
    
    # Détecter l'architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ]; then
        AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
    else
        AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    fi
    
    echo "Téléchargement d'AWS CLI..."
    curl "$AWS_CLI_URL" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Erreur: Installation d'AWS CLI échouée${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}AWS CLI installé avec succès !${NC}"
fi

echo -e "${BLUE}Configuration d'AWS CLI avec vos identifiants...${NC}"
echo ""

# Lire les identifiants depuis le fichier .env
if [ -f ".env" ]; then
    source .env
    echo -e "${GREEN}Identifiants trouvés dans .env${NC}"
    
    AWS_ACCESS_KEY_ID="$cle_acces"
    AWS_SECRET_ACCESS_KEY="$secret_key_aws"
    
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo -e "${RED}Erreur: Identifiants manquants dans .env${NC}"
        exit 1
    fi
else
    echo -e "${RED}Fichier .env non trouvé${NC}"
    exit 1
fi

# Proposer une région par défaut
echo -e "${YELLOW}Régions AWS populaires pour la configuration par défaut:${NC}"
echo "1. eu-west-3 (Paris, France)"
echo "2. eu-central-1 (Francfort, Allemagne)" 
echo "3. us-east-1 (Virginie, États-Unis)"
echo ""
read -p "Choisissez votre région par défaut (1-3): " REGION_CHOICE

case $REGION_CHOICE in
    1) DEFAULT_REGION="eu-west-3" ;;
    2) DEFAULT_REGION="eu-central-1" ;;
    3) DEFAULT_REGION="us-east-1" ;;
    *) DEFAULT_REGION="eu-west-3" ;;
esac

# Configurer AWS CLI
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$DEFAULT_REGION"
aws configure set default.output "json"

# Tester la configuration
echo ""
echo -e "${BLUE}Test de la configuration...${NC}"
if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}PASS: Configuration AWS réussie !${NC}"
    echo ""
    aws sts get-caller-identity
    echo ""
    echo -e "${GREEN}Vous êtes prêt à déployer votre VPN !${NC}"
    echo -e "${BLUE}Prochaine étape: ./deploy_vpn.sh${NC}"
else
    echo -e "${RED}FAIL: Erreur de configuration AWS${NC}"
    echo "Vérifiez vos identifiants dans le fichier .env"
    exit 1
fi
