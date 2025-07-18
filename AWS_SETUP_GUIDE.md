# Guide AWS - Création des Clés d'Accès

## 🎯 Objectif
Obtenir les clés AWS nécessaires pour déployer votre VPN WireGuard.

## 📋 Étapes Détaillées

### 1. Connexion à AWS
1. Allez sur https://console.aws.amazon.com/
2. Connectez-vous avec votre compte AWS
3. Si vous n'avez pas de compte, créez-en un (Free Tier inclus)

### 2. Accès au Service IAM
1. Dans la barre de recherche AWS, tapez "IAM"
2. Cliquez sur "IAM" (Identity and Access Management)
3. Dans le menu de gauche, cliquez sur "Utilisateurs"

### 3. Création d'un Utilisateur
1. Cliquez sur "Créer un utilisateur" ou "Add user"
2. **Nom d'utilisateur** : `vpn-deployment-user` (ou votre choix)
3. **Type d'accès** : Cochez "Accès programmatique" / "Programmatic access"
4. Cliquez "Suivant"

### 4. Attribution des Permissions
**Option Simple (recommandée pour débuter) :**
1. Sélectionnez "Attacher des stratégies existantes directement"
2. Recherchez et cochez :
   - `EC2FullAccess`
   - `VPCFullAccess`
3. Cliquez "Suivant"

**Option Avancée (plus sécurisée) :**
Créez une politique personnalisée avec seulement les permissions nécessaires.

### 5. Révision et Création
1. Vérifiez les informations
2. Cliquez "Créer un utilisateur"

### 6. Récupération des Clés
🚨 **IMPORTANT** : Cette étape ne peut être faite qu'UNE SEULE FOIS !

1. Sur la page de succès, vous verrez :
   - **Access Key ID** : Format `AKIA...` (20 caractères)
   - **Secret Access Key** : (40 caractères avec lettres/chiffres/symboles)

2. **COPIEZ CES VALEURS IMMÉDIATEMENT** dans votre fichier `.env`

3. Pour sauvegarder :
   - Cliquez "Télécharger .csv" (recommandé)
   - Ou notez les clés dans un endroit sûr

## 🔧 Configuration dans le Projet

### Modification du fichier .env
```bash
# Dans votre projet VPN
cp .env.example .env
nano .env

# Remplacez les exemples par vos vraies clés :
AWS_ACCESS_KEY_ID=AKIA1234567890EXAMPLE      # Votre vraie clé
AWS_SECRET_ACCESS_KEY=VotreVraieClé40Caractères/Avec+Des/Symboles
```

### Exemple de Format Attendu
```
✅ CORRECT:
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

❌ INCORRECT:
AWS_ACCESS_KEY_ID=ma-clé-aws
AWS_SECRET_ACCESS_KEY=mon-secret
```

## 🔐 Sécurité et Bonnes Pratiques

### ✅ À Faire
- Gardez vos clés secrètes et ne les partagez jamais
- Le fichier `.env` est protégé par `.gitignore`
- Téléchargez le CSV de sauvegarde AWS
- Créez un utilisateur dédié pour le VPN

### ❌ À Éviter
- Ne jamais commiter les clés dans Git
- Ne pas utiliser vos clés root/administrateur
- Ne pas partager vos clés par email/chat
- Ne pas laisser les clés d'exemple

## 🚨 Que Faire si Vous Perdez vos Clés

1. Retournez dans IAM → Utilisateurs
2. Sélectionnez votre utilisateur VPN
3. Onglet "Clés d'accès"
4. Créez une nouvelle clé d'accès
5. Supprimez l'ancienne clé après avoir testé la nouvelle

## ✅ Validation
Après configuration, testez avec :
```bash
./validate_config.sh
```

Vous devriez voir :
```
✅ AWS_ACCESS_KEY_ID configuré
✅ AWS_SECRET_ACCESS_KEY configuré
✅ Connexion AWS réussie
```

## 🆘 Dépannage

### Erreur "Access Denied"
- Vérifiez que les permissions EC2FullAccess et VPCFullAccess sont attachées
- Attendez 1-2 minutes après création (propagation des permissions)

### Erreur "Invalid Security Token"
- Vérifiez que vos clés sont exactement copiées (pas d'espaces)
- Assurez-vous d'utiliser les bonnes clés (pas les exemples)

### Erreur "User does not exist"
- Vérifiez que l'utilisateur IAM existe toujours
- Vérifiez la région AWS dans votre fichier .env

---

🎉 **Une fois configuré, vous pourrez déployer votre VPN avec `./deploy_vpn.sh` !**
