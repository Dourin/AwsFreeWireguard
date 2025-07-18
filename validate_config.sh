#!/bin/bash

#===============================================================================
# VPN WireGuard Configuration Validation Script
# Author: MUNCIULEANU DORIN
# Description: Validate system requirements and configuration before deployment
# Version: 1.0
# License: MIT
#===============================================================================

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== VPN Configuration Validation ===${NC}"
echo ""

# Vérifier si les outils sont installés
echo -e "${BLUE}Vérification des prérequis...${NC}"

# Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version | head -n1 | cut -d' ' -f2)
    echo -e "${GREEN}PASS: Terraform installé : $TERRAFORM_VERSION${NC}"
else
    echo -e "${RED}FAIL: Terraform non installé${NC}"
    echo "   Installation: https://www.terraform.io/downloads.html"
fi

# AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version | cut -d' ' -f1)
    echo -e "${GREEN}PASS: AWS CLI installé : $AWS_VERSION${NC}"
else
    echo -e "${RED}FAIL: AWS CLI non installé${NC}"
    echo "   Installation: https://aws.amazon.com/cli/"
fi

# qrencode
if command -v qrencode &> /dev/null; then
    echo -e "${GREEN}PASS: qrencode installé${NC}"
else
    echo -e "${YELLOW}WARNING: qrencode non installé (optionnel pour QR codes)${NC}"
    echo "   Installation: sudo apt install qrencode (Ubuntu/Debian)"
fi

echo ""

# Vérifier les fichiers de configuration
echo -e "${BLUE}Vérification des fichiers de configuration...${NC}"

if [ -f ".env" ]; then
    echo -e "${GREEN}PASS: Fichier .env présent${NC}"
    
    # Vérifier que les variables sont configurées
    source .env 2>/dev/null
    
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ "$AWS_ACCESS_KEY_ID" != "your_aws_access_key_id_here" ] && [ "$AWS_ACCESS_KEY_ID" != "AKIAIOSFODNN7EXAMPLE" ]; then
        echo -e "${GREEN}PASS: AWS_ACCESS_KEY_ID configuré${NC}"
    else
        echo -e "${RED}FAIL: AWS_ACCESS_KEY_ID non configuré dans .env${NC}"
        if [ "$AWS_ACCESS_KEY_ID" = "AKIAIOSFODNN7EXAMPLE" ]; then
            echo -e "${YELLOW}   WARNING: Vous utilisez encore l'exemple. Remplacez par votre vraie clé AWS.${NC}"
        fi
    fi
    
    if [ -n "$AWS_SECRET_ACCESS_KEY" ] && [ "$AWS_SECRET_ACCESS_KEY" != "your_aws_secret_access_key_here" ] && [ "$AWS_SECRET_ACCESS_KEY" != "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" ]; then
        echo -e "${GREEN}PASS: AWS_SECRET_ACCESS_KEY configuré${NC}"
    else
        echo -e "${RED}FAIL: AWS_SECRET_ACCESS_KEY non configuré dans .env${NC}"
        if [ "$AWS_SECRET_ACCESS_KEY" = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" ]; then
            echo -e "${YELLOW}   WARNING: Vous utilisez encore l'exemple. Remplacez par votre vraie clé AWS.${NC}"
        fi
    fi
    
    if [ -n "$AWS_DEFAULT_REGION" ]; then
        echo -e "${GREEN}PASS: Région AWS : $AWS_DEFAULT_REGION${NC}"
    else
        echo -e "${YELLOW}WARNING: Région AWS non définie${NC}"
    fi
    
else
    echo -e "${RED}FAIL: Fichier .env manquant${NC}"
    echo "   Copiez .env.example vers .env et configurez-le"
fi

if [ -f ".env.example" ]; then
    echo -e "${GREEN}PASS: Fichier .env.example présent${NC}"
else
    echo -e "${YELLOW}WARNING: Fichier .env.example manquant${NC}"
fi

echo ""

# Vérifier les permissions des scripts
echo -e "${BLUE}Vérification des permissions des scripts...${NC}"

for script in deploy_vpn.sh destroy_vpn.sh start_vpn.sh stop_vpn.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo -e "${GREEN}PASS: $script exécutable${NC}"
        else
            echo -e "${YELLOW}WARNING: $script non exécutable${NC}"
            echo "   Correction: chmod +x $script"
        fi
    else
        echo -e "${RED}FAIL: $script manquant${NC}"
    fi
done

echo ""

# Test de connectivité AWS (si configuré)
echo -e "${BLUE}Test de connectivité AWS...${NC}"

if [ -f ".env" ]; then
    source .env 2>/dev/null
    
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ "$AWS_ACCESS_KEY_ID" != "your_aws_access_key_id_here" ]; then
        if aws sts get-caller-identity --no-cli-pager &> /dev/null; then
            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --no-cli-pager 2>/dev/null)
            USER_ARN=$(aws sts get-caller-identity --query Arn --output text --no-cli-pager 2>/dev/null)
            echo -e "${GREEN}PASS: Connexion AWS réussie${NC}"
            echo "   Compte AWS: $ACCOUNT_ID"
            echo "   Utilisateur: $USER_ARN"
        else
            echo -e "${RED}FAIL: Impossible de se connecter à AWS${NC}"
            echo "   Vérifiez vos clés AWS dans .env"
        fi
    else
        echo -e "${YELLOW}WARNING: Clés AWS non configurées - test ignoré${NC}"
    fi
else
    echo -e "${YELLOW}WARNING: Fichier .env manquant - test ignoré${NC}"
fi

echo ""

# Vérifier l'état du déploiement actuel
echo -e "${BLUE}État du déploiement actuel...${NC}"

if [ -d "terraform" ]; then
    echo -e "${GREEN}PASS: Dossier terraform présent${NC}"
    
    if [ -f "terraform/terraform.tfstate" ]; then
        echo -e "${GREEN}PASS: Infrastructure déployée détectée${NC}"
        
        # Vérifier si l'instance est active
        if [ -f ".env" ]; then
            source .env 2>/dev/null
            INSTANCE_ID=$(cd terraform && terraform output -raw instance_id 2>/dev/null)
            
            if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "" ]; then
                INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text --no-cli-pager 2>/dev/null)
                
                case $INSTANCE_STATE in
                    "running")
                        echo -e "${GREEN}PASS: Instance EC2 en cours d'exécution${NC}"
                        PUBLIC_IP=$(cd terraform && terraform output -raw server_public_ip 2>/dev/null)
                        echo "   IP publique: $PUBLIC_IP"
                        ;;
                    "stopped")
                        echo -e "${YELLOW}WARNING: Instance EC2 arrêtée${NC}"
                        echo "   Utilisez ./start_vpn.sh pour redémarrer"
                        ;;
                    "pending"|"stopping"|"starting")
                        echo -e "${BLUE}INFO: Instance EC2 en transition ($INSTANCE_STATE)${NC}"
                        ;;
                    *)
                        echo -e "${RED}FAIL: État instance inconnu: $INSTANCE_STATE${NC}"
                        ;;
                esac
            fi
        fi
    else
        echo -e "${YELLOW}WARNING: Aucune infrastructure déployée${NC}"
        echo "   Utilisez ./deploy_vpn.sh pour commencer"
    fi
else
    echo -e "${RED}FAIL: Dossier terraform manquant${NC}"
fi

echo ""
echo -e "${BLUE}=== Résumé des actions recommandées ===${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${YELLOW}INSTALL: Installer Terraform${NC}"
fi

if ! command -v aws &> /dev/null; then
    echo -e "${YELLOW}INSTALL: Installer AWS CLI${NC}"
fi

if [ ! -f ".env" ]; then
    echo -e "${YELLOW}CONFIG: Créer et configurer le fichier .env${NC}"
    echo "   cp .env.example .env && nano .env"
fi

if [ -f ".env" ]; then
    source .env 2>/dev/null
    if [ "$AWS_ACCESS_KEY_ID" = "your_aws_access_key_id_here" ] || [ "$AWS_ACCESS_KEY_ID" = "AKIAIOSFODNN7EXAMPLE" ]; then
        echo -e "${YELLOW}KEY: Configurer les clés AWS dans .env${NC}"
        echo -e "${BLUE}   INFO: Guide: Console AWS → IAM → Utilisateurs → Créer utilisateur → Accès programmatique${NC}"
        echo -e "${BLUE}   INFO: Permissions: EC2FullAccess, VPCFullAccess${NC}"
        echo -e "${BLUE}   INFO: Format attendu: AKIA... (Access Key) et clé secrète 40 caractères${NC}"
    fi
fi

# Vérifier les permissions
for script in deploy_vpn.sh destroy_vpn.sh start_vpn.sh stop_vpn.sh; do
    if [ -f "$script" ] && [ ! -x "$script" ]; then
        echo -e "${YELLOW}FIX: Rendre $script exécutable: chmod +x $script${NC}"
    fi
done

echo ""
echo -e "${GREEN}Configuration terminée ! Utilisez ./deploy_vpn.sh pour commencer.${NC}"
