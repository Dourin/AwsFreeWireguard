#!/bin/bash

#===============================================================================
# VPN WireGuard Instance Stop Script
# Author: MUNCIULEANU DORIN
# Description: Stop EC2 instance to save costs while preserving infrastructure
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
else
    echo -e "${RED}Erreur: Fichier .env non trouvé.${NC}"
    exit 1
fi

echo -e "${BLUE}=== VPN Server Shutdown ===${NC}"
echo ""

# Aller dans le dossier terraform
cd "$(dirname "$0")/terraform"

# Vérifier si Terraform est initialisé
if [ ! -d ".terraform" ]; then
    echo -e "${RED}Erreur: Infrastructure non déployée. Utilisez d'abord ./deploy_vpn.sh${NC}"
    exit 1
fi

# Récupérer l'ID de l'instance
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
if [ -z "$INSTANCE_ID" ]; then
    echo -e "${RED}Erreur: Impossible de récupérer l'ID de l'instance.${NC}"
    exit 1
fi

REGION=$(terraform output -raw server_region 2>/dev/null)
if [ -z "$REGION" ]; then
    REGION="${AWS_DEFAULT_REGION:-eu-west-3}"
fi

echo -e "${YELLOW}Instance à arrêter: $INSTANCE_ID${NC}"
echo -e "${YELLOW}Région: $REGION${NC}"

# Vérifier l'état actuel de l'instance
CURRENT_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text --no-cli-pager 2>/dev/null)

if [ "$CURRENT_STATE" == "stopped" ]; then
    echo -e "${GREEN}L'instance est déjà arrêtée.${NC}"
    exit 0
elif [ "$CURRENT_STATE" == "stopping" ]; then
    echo -e "${YELLOW}L'instance est en cours d'arrêt...${NC}"
    exit 0
elif [ "$CURRENT_STATE" != "running" ]; then
    echo -e "${RED}État de l'instance non reconnu: $CURRENT_STATE${NC}"
    exit 1
fi

# Demander confirmation
if [[ "$1" != "--force" ]]; then
    echo -e "${YELLOW}ATTENTION: Cette opération va arrêter l'instance EC2.${NC}"
    echo -e "${YELLOW}Le VPN sera inaccessible jusqu'au redémarrage.${NC}"
    echo -e "${GREEN}Avantage: Aucun frais de calcul pendant l'arrêt (seul le stockage EBS facturé).${NC}"
    echo ""
    read -p "Voulez-vous continuer ? (oui/non): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[oO][uU][iI]$ ]]; then
        echo -e "${YELLOW}Arrêt annulé.${NC}"
        exit 0
    fi
fi

# Arrêter l'instance
echo -e "${BLUE}Arrêt de l'instance en cours...${NC}"
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION --no-cli-pager > /dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Instance arrêtée avec succès !${NC}"
    echo ""
    echo -e "${BLUE}Informations importantes:${NC}"
    echo "- L'instance est maintenant arrêtée"
    echo "- Aucun frais de calcul ne sera généré"
    echo "- Seul le stockage EBS (environ $0.10/mois pour 8GB) sera facturé"
    echo "- Pour redémarrer: ./start_vpn.sh"
    echo ""
    echo -e "${YELLOW}Note: L'adresse IP publique changera lors du redémarrage.${NC}"
    echo -e "${YELLOW}Vous devrez récupérer la nouvelle configuration client.${NC}"
else
    echo -e "${RED}Erreur lors de l'arrêt de l'instance.${NC}"
    exit 1
fi
