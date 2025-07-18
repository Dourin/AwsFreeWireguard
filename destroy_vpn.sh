#!/bin/bash

#===============================================================================
# VPN WireGuard Infrastructure Destruction Script
# Author: MUNCIULEANU DORIN
# Description: Clean destruction of AWS infrastructure to avoid charges
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
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Erreur: Fichier .env non trouvé.${NC}"
    exit 1
fi

echo -e "${RED}=== Destruction du VPN WireGuard sur AWS ===${NC}"
echo ""

# Vérifier si Terraform est installé
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Erreur: Terraform n'est pas installé.${NC}"
    exit 1
fi

# Aller dans le dossier terraform
cd "$(dirname "$0")/terraform"

# Vérifier si un état Terraform existe
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}Aucun état Terraform trouvé. Il se peut qu'aucune ressource ne soit déployée.${NC}"
    read -p "Voulez-vous continuer quand même ? (oui/non): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[oO][uU][iI]$ ]]; then
        echo -e "${YELLOW}Opération annulée.${NC}"
        exit 0
    fi
fi

# Afficher les ressources qui seront détruites
echo -e "${BLUE}Ressources qui seront détruites:${NC}"
terraform plan -destroy 2>/dev/null | grep -E "(will be destroyed|Plan:|No changes)"

echo ""
echo -e "${RED}WARNING: This operation will destroy ALL associated AWS resources${NC}"
echo -e "${RED}This action is IRREVERSIBLE${NC}"
echo ""

# Vérifier si mode force est activé
if [[ "$1" == "--force" ]]; then
    echo -e "${YELLOW}Mode force activé - Destruction automatique${NC}"
else
    # Double confirmation pour éviter les erreurs
    read -p "Tapez 'DETRUIRE' en majuscules pour confirmer: " CONFIRM1
    if [ "$CONFIRM1" != "DETRUIRE" ]; then
        echo -e "${YELLOW}Première confirmation échouée. Opération annulée.${NC}"
        exit 0
    fi

    read -p "Êtes-vous ABSOLUMENT SÛR de vouloir détruire le VPN ? (oui/non): " CONFIRM2
    if [[ ! "$CONFIRM2" =~ ^[oO][uU][iI]$ ]]; then
        echo -e "${YELLOW}Deuxième confirmation échouée. Opération annulée.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}Initialisation de Terraform...${NC}"
terraform init

# Détruire les ressources Terraform
echo -e "${RED}Lancement de la destruction...${NC}"
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=== Destruction terminée avec succès ! ===${NC}"
    echo ""
    
    # Définir la région pour les vérifications
    REGION="${AWS_DEFAULT_REGION:-eu-west-3}"
    
    # Nettoyer les fichiers locaux de manière exhaustive
    echo -e "${BLUE}Nettoyage complet des fichiers locaux...${NC}"
    
    # Nettoyer tous les fichiers de configuration et clés
    rm -f ssh_key.pem
    rm -f client*.conf
    rm -f client*_qr.*
    rm -f client*_private.key
    rm -f client*_public.key
    rm -f server_private.key
    rm -f server_public.key
    rm -f ../deployment_info.txt
    
    # Nettoyer les fichiers Terraform de sauvegarde
    rm -f terraform.tfstate.backup*
    rm -f .terraform.lock.hcl
    
    # Nettoyer le dossier .terraform si présent
    rm -rf .terraform/
    
    echo -e "${GREEN}Tous les fichiers locaux ont été supprimés.${NC}"
    
    # Vérification finale des ressources AWS
    echo -e "${BLUE}Vérification finale des ressources AWS...${NC}"
    
    # Vérifier qu'aucune instance EC2 avec notre tag n'existe
    INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=wireguard-vpn-server" "Name=instance-state-name,Values=running,pending,stopping,stopped" --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || echo "")
    
    if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ]; then
        echo -e "${YELLOW}Warning: EC2 instances detected:${NC}"
        echo "$INSTANCES"
        echo -e "${YELLOW}Please verify them manually in AWS console.${NC}"
    else
        echo -e "${GREEN}No EC2 instances detected.${NC}"
    fi
    
    # Vérifier les Security Groups
    SG=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=${SECURITY_GROUP_NAME:-wireguard-security-group}*" --query "SecurityGroups[*].GroupId" --output text --no-cli-pager 2>/dev/null || echo "")
    
    if [ -n "$SG" ] && [ "$SG" != "None" ]; then
        echo -e "${YELLOW}Warning: Security Groups still present: $SG${NC}"
        echo -e "${YELLOW}Suppression en cours...${NC}"
        for sg_id in $SG; do
            aws ec2 delete-security-group --group-id $sg_id --region $REGION --no-cli-pager > /dev/null 2>&1 || echo "Impossible de supprimer $sg_id"
        done
    else
        echo -e "${GREEN}No Security Groups detected.${NC}"
    fi
    
    # Vérifier les Key Pairs
    KP=$(aws ec2 describe-key-pairs --region $REGION --filters "Name=key-name,Values=${KEY_PAIR_NAME:-wireguard-vpn-key}" --query "KeyPairs[*].KeyName" --output text --no-cli-pager 2>/dev/null || echo "")
    
    if [ -n "$KP" ] && [ "$KP" != "None" ]; then
        echo -e "${YELLOW}Warning: Key Pairs still present: $KP${NC}"
        echo -e "${YELLOW}Suppression en cours...${NC}"
        for kp_name in $KP; do
            aws ec2 delete-key-pair --key-name $kp_name --region $REGION --no-cli-pager > /dev/null 2>&1 || echo "Impossible de supprimer $kp_name"
        done
    else
        echo -e "${GREEN}No Key Pairs detected.${NC}"
    fi

    # Vérifier les instances EC2 (avec terminaison forcée si nécessaire)
    INSTANCES=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=${INSTANCE_NAME:-wireguard-vpn-server}" --query 'Reservations[*].Instances[?State.Name!=`terminated`].InstanceId' --output text --no-cli-pager 2>/dev/null)
    if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ]; then
        echo -e "${YELLOW}Warning: EC2 instances still present: $INSTANCES${NC}"
        echo -e "${YELLOW}Terminaison forcée...${NC}"
        aws ec2 terminate-instances --instance-ids $INSTANCES --region $REGION --no-cli-pager > /dev/null 2>&1
        echo "Instances marquées pour terminaison."
    else
        echo -e "${GREEN}No EC2 instances detected.${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}All AWS resources have been removed.${NC}"
    echo -e "${GREEN}No charges should be generated.${NC}"
    echo ""
    echo -e "${BLUE}Recommandations:${NC}"
    echo "1. Vérifiez votre console AWS pour confirmer la suppression"
    echo "2. Consultez la section facturation AWS dans 24-48h"
    echo "3. Les connexions VPN existantes seront automatiquement fermées"
    echo ""
else
    echo ""
    echo -e "${RED}Error during destruction!${NC}"
    echo ""
    echo -e "${YELLOW}Actions recommandées:${NC}"
    echo "1. Vérifiez les messages d'erreur ci-dessus"
    echo "2. Consultez votre console AWS manuellement"
    echo "3. Supprimez manuellement les ressources si nécessaire:"
    echo "   - Instance EC2 'wireguard-vpn-server'"
    echo "   - Security Group 'wireguard-security-group'"
    echo "   - Key Pair 'wireguard-vpn-key'"
    echo "4. Relancez ce script si les erreurs sont corrigées"
    echo ""
    echo -e "${RED}IMPORTANT: Check your AWS console to avoid charges!${NC}"
    exit 1
fi
