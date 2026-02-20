#!/bin/bash

#############################################
# Script de création de base de données MySQL
# Usage: ./create_db.sh nom_du_projet
#############################################

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour générer un mot de passe fort
generate_password() {
    # Génère un mot de passe de 24 caractères avec majuscules, minuscules, chiffres et caractères spéciaux
    tr -dc 'A-Za-z0-9!@#$%^&*()_+=-' < /dev/urandom | head -c 24
}

# Fonction pour afficher l'usage
usage() {
    echo -e "${YELLOW}Usage: $0 nom_du_projet${NC}"
    echo "Exemple: $0 monapp"
    exit 1
}

# Vérifier qu'un paramètre est fourni
if [ $# -eq 0 ]; then
    echo -e "${RED}Erreur: Aucun nom de projet fourni${NC}"
    usage
fi

PROJECT_NAME=$1

# Validation du nom de projet (alphanumerique et underscore seulement)
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo -e "${RED}Erreur: Le nom du projet doit contenir uniquement des lettres, chiffres et underscores${NC}"
    exit 1
fi

# Définition des variables
DB_NAME="${PROJECT_NAME}DB"
DB_USER="${PROJECT_NAME}UDB"
DB_PASSWORD=$(generate_password)
MYSQL_ROOT_PASSWORD=""

# Demander le mot de passe root MySQL
echo -e "${YELLOW}Entrez le mot de passe root MySQL:${NC}"
read -s MYSQL_ROOT_PASSWORD
echo ""

# Vérifier la connexion MySQL
if ! mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}Erreur: Impossible de se connecter à MySQL avec les identifiants fournis${NC}"
    exit 1
fi

echo -e "${GREEN}Connexion MySQL réussie${NC}"
echo ""

# Créer la base de données
echo -e "${YELLOW}Création de la base de données: ${DB_NAME}${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Base de données créée${NC}"
else
    echo -e "${RED}✗ Erreur lors de la création de la base${NC}"
    exit 1
fi

# Créer l'utilisateur
echo -e "${YELLOW}Création de l'utilisateur: ${DB_USER}${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Utilisateur créé${NC}"
else
    echo -e "${RED}✗ Erreur lors de la création de l'utilisateur${NC}"
    exit 1
fi

# Donner tous les privilèges sur la base
echo -e "${YELLOW}Attribution des privilèges...${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Privilèges accordés${NC}"
else
    echo -e "${RED}✗ Erreur lors de l'attribution des privilèges${NC}"
    exit 1
fi

# Retirer le privilège GRANT
echo -e "${YELLOW}Retrait du privilège GRANT...${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
REVOKE GRANT OPTION ON \`${DB_NAME}\`.* FROM '${DB_USER}'@'localhost';
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Privilège GRANT retiré${NC}"
else
    echo -e "${RED}✗ Erreur lors du retrait du privilège GRANT${NC}"
    exit 1
fi

# Flush des privilèges
echo -e "${YELLOW}Flush des privilèges...${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Privilèges actualisés${NC}"
else
    echo -e "${RED}✗ Erreur lors du flush des privilèges${NC}"
    exit 1
fi

# Sauvegarder les informations dans un fichier
CREDENTIALS_FILE="${PROJECT_NAME}_credentials.txt"
cat > "$CREDENTIALS_FILE" <<EOF
#############################################
# Identifiants de base de données
# Projet: ${PROJECT_NAME}
# Créé le: $(date '+%Y-%m-%d %H:%M:%S')
#############################################

Base de données: ${DB_NAME}
Utilisateur: ${DB_USER}
Mot de passe: ${DB_PASSWORD}
Host: localhost

# Chaîne de connexion PHP (mysqli)
\$host = 'localhost';
\$dbname = '${DB_NAME}';
\$username = '${DB_USER}';
\$password = '${DB_PASSWORD}';

# Chaîne de connexion PDO
\$dsn = 'mysql:host=localhost;dbname=${DB_NAME};charset=utf8mb4';
\$username = '${DB_USER}';
\$password = '${DB_PASSWORD}';

# URL de connexion (pour .env)
DATABASE_URL="mysql://${DB_USER}:${DB_PASSWORD}@localhost:3306/${DB_NAME}?charset=utf8mb4"

#############################################
# IMPORTANT: Conservez ce fichier en lieu sûr
# et supprimez-le après avoir noté les identifiants
#############################################
EOF

# Sécuriser le fichier (lecture seule pour le propriétaire)
chmod 600 "$CREDENTIALS_FILE"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           BASE DE DONNÉES CRÉÉE AVEC SUCCÈS            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Informations de connexion:${NC}"
echo -e "  Base de données: ${GREEN}${DB_NAME}${NC}"
echo -e "  Utilisateur:     ${GREEN}${DB_USER}${NC}"
echo -e "  Mot de passe:    ${GREEN}${DB_PASSWORD}${NC}"
echo -e "  Host:            ${GREEN}localhost${NC}"
echo ""
echo -e "${YELLOW}Les identifiants ont été sauvegardés dans:${NC} ${GREEN}${CREDENTIALS_FILE}${NC}"
echo -e "${RED}⚠ ATTENTION: Conservez ce fichier en lieu sûr et supprimez-le après usage${NC}"
echo ""

# Tester la connexion avec le nouvel utilisateur
echo -e "${YELLOW}Test de connexion avec le nouvel utilisateur...${NC}"
if mysql -u "$DB_USER" -p"$DB_PASSWORD" -e "USE \`${DB_NAME}\`; SELECT 'Connexion réussie!' as Status;" 2>/dev/null; then
    echo -e "${GREEN}✓ Test de connexion réussi${NC}"
else
    echo -e "${RED}✗ Erreur lors du test de connexion${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Configuration terminée !${NC}"
