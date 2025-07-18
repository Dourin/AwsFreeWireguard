#!/bin/bash

#===============================================================================
# VPN WireGuard Instance Start Script
# Author: MUNCIULEANU DORIN
# Description: Start stopped EC2 instance and reconfigure WireGuard
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

echo -e "${BLUE}=== VPN Server Startup ===${NC}"
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

echo -e "${YELLOW}Instance à démarrer: $INSTANCE_ID${NC}"
echo -e "${YELLOW}Région: $REGION${NC}"

# Vérifier l'état actuel de l'instance
CURRENT_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text --no-cli-pager 2>/dev/null)

if [ "$CURRENT_STATE" == "running" ]; then
    echo -e "${GREEN}L'instance est déjà en cours d'exécution.${NC}"
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --no-cli-pager 2>/dev/null)
    echo -e "${GREEN}IP actuelle: $PUBLIC_IP${NC}"
    exit 0
elif [ "$CURRENT_STATE" == "pending" ]; then
    echo -e "${YELLOW}L'instance est en cours de démarrage...${NC}"
    exit 0
elif [ "$CURRENT_STATE" != "stopped" ]; then
    echo -e "${RED}État de l'instance non compatible pour le démarrage: $CURRENT_STATE${NC}"
    exit 1
fi

# Démarrer l'instance
echo -e "${BLUE}Démarrage de l'instance en cours...${NC}"
aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION --no-cli-pager > /dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Erreur lors du démarrage de l'instance.${NC}"
    exit 1
fi

echo -e "${YELLOW}Attente du démarrage complet...${NC}"

# Attendre que l'instance soit en état "running"
for i in {1..30}; do
    CURRENT_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text --no-cli-pager 2>/dev/null)
    if [ "$CURRENT_STATE" == "running" ]; then
        break
    fi
    echo "Tentative $i/30... État: $CURRENT_STATE"
    sleep 10
done

if [ "$CURRENT_STATE" != "running" ]; then
    echo -e "${RED}L'instance n'a pas pu démarrer dans les temps impartis.${NC}"
    exit 1
fi

# Récupérer la nouvelle IP publique
echo -e "${BLUE}Récupération de la nouvelle adresse IP...${NC}"
sleep 5

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --no-cli-pager 2>/dev/null)

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "None" ]; then
    echo -e "${RED}Impossible de récupérer l'adresse IP publique.${NC}"
    exit 1
fi

echo -e "${GREEN}Instance démarrée avec succès !${NC}"
echo -e "${GREEN}Nouvelle IP publique: $PUBLIC_IP${NC}"
echo ""

# Attendre que les services soient prêts
echo -e "${YELLOW}Attente de la disponibilité des services (2-3 minutes)...${NC}"
sleep 120

# Récupérer la clé SSH
SSH_KEY="ssh_key.pem"
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${BLUE}Récupération de la clé SSH...${NC}"
    terraform output -raw ssh_private_key > $SSH_KEY
    chmod 600 $SSH_KEY
fi

# Tester la connexion SSH
echo -e "${BLUE}Test de la connexion SSH...${NC}"
for i in {1..10}; do
    if ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PUBLIC_IP "echo 'SSH OK'" &>/dev/null; then
        echo -e "${GREEN}Connexion SSH établie !${NC}"
        break
    fi
    echo "Tentative $i/10..."
    sleep 10
done

# Vérifier l'état du service WireGuard
echo -e "${BLUE}Vérification du service WireGuard...${NC}"
WG_STATUS=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "sudo systemctl is-active wg-quick@wg0" 2>/dev/null || echo "inactive")

if [ "$WG_STATUS" == "active" ]; then
    echo -e "${GREEN}Service WireGuard actif !${NC}"
else
    echo -e "${YELLOW}Redémarrage du service WireGuard...${NC}"
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "sudo systemctl restart wg-quick@wg0" 2>/dev/null
    sleep 5
fi

# Mettre à jour les configurations client avec la nouvelle IP
echo -e "${BLUE}Mise à jour des configurations client...${NC}"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "
cd /home/ubuntu
for i in {1..5}; do
    if [ -f client\${i}.conf ]; then
        sed -i \"s/Endpoint = .*/Endpoint = $PUBLIC_IP:51820/\" client\${i}.conf
        qrencode -t ansiutf8 < client\${i}.conf > client\${i}_qr.txt 2>/dev/null || true
        qrencode -t png -o client\${i}_qr.png < client\${i}.conf 2>/dev/null || true
    fi
done
"

# Récupérer la nouvelle configuration
if ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "cat client1.conf" > client1.conf 2>/dev/null; then
    echo -e "${GREEN}Configuration client mise à jour: client1.conf${NC}"
fi

echo ""
echo -e "${GREEN}=== Serveur VPN redémarré avec succès ! ===${NC}"
echo ""
echo -e "${BLUE}Informations mises à jour:${NC}"
echo "- Nouvelle IP: $PUBLIC_IP"
echo "- Configuration client: $(pwd)/client1.conf"
echo "- Connexion SSH: ssh -i $SSH_KEY ubuntu@$PUBLIC_IP"
echo ""
echo -e "${YELLOW}Important: Reconfigurez vos clients avec la nouvelle configuration !${NC}"
