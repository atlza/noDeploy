#!/bin/bash

#############################################
# Script de restauration de base de données
# Usage: ./restore_db.sh fichier_backup.sql.gz
#############################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo -e "${YELLOW}Usage: $0 fichier_backup.sql.gz [nom_nouvelle_base]${NC}"
    echo ""
    echo "Exemple: $0 monappDB_backup_20240220_153045.sql.gz"
    echo "Exemple: $0 monappDB_backup_20240220_153045.sql.gz nouvelle_base"
    exit 1
}

if [ $# -eq 0 ]; then
    echo -e "${RED}Erreur: Aucun fichier de backup fourni${NC}"
    usage
fi

BACKUP_FILE=$1
NEW_DB_NAME=$2

# Vérifier que le fichier existe
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Erreur: Le fichier '$BACKUP_FILE' n'existe pas${NC}"
    exit 1
fi

# Lire les métadonnées si disponibles
METADATA_FILE="${BACKUP_FILE}.info"
if [ -f "$METADATA_FILE" ]; then
    echo -e "${BLUE}Informations du backup:${NC}"
    cat "$METADATA_FILE"
    echo ""
fi

# Extraire le nom de la base depuis le backup (première ligne CREATE DATABASE)
ORIGINAL_DB_NAME=$(zcat "$BACKUP_FILE" | grep -m1 "CREATE DATABASE" | sed -E 's/.*`([^`]+)`.*/\1/')

if [ -z "$ORIGINAL_DB_NAME" ]; then
    echo -e "${RED}Erreur: Impossible de déterminer le nom de la base depuis le backup${NC}"
    exit 1
fi

echo -e "${BLUE}Base de données d'origine: ${YELLOW}${ORIGINAL_DB_NAME}${NC}"

# Si pas de nouveau nom spécifié, demander confirmation
if [ -z "$NEW_DB_NAME" ]; then
    echo -e "${YELLOW}Restaurer vers la base d'origine '${ORIGINAL_DB_NAME}' ? (o/N)${NC}"
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Oo]$ ]]; then
        echo -e "${YELLOW}Entrez le nom de la nouvelle base:${NC}"
        read -r NEW_DB_NAME
    else
        NEW_DB_NAME="$ORIGINAL_DB_NAME"
    fi
fi

echo ""
echo -e "${YELLOW}Base de destination: ${GREEN}${NEW_DB_NAME}${NC}"
echo ""

# Demander le mot de passe root
echo -e "${YELLOW}Entrez le mot de passe root MySQL:${NC}"
read -s MYSQL_ROOT_PASSWORD
echo ""

# Vérifier la connexion
if ! mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}Erreur: Impossible de se connecter à MySQL${NC}"
    exit 1
fi

echo -e "${GREEN}Connexion MySQL réussie${NC}"
echo ""

# Vérifier si la base existe déjà
DB_EXISTS=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${NEW_DB_NAME}';" -sN)

if [ -n "$DB_EXISTS" ]; then
    echo -e "${RED}⚠️  La base '${NEW_DB_NAME}' existe déjà${NC}"
    echo -e "${YELLOW}Voulez-vous la remplacer? (o/N)${NC}"
    read -r REPLACE
    if [[ ! "$REPLACE" =~ ^[Oo]$ ]]; then
        echo -e "${GREEN}Restauration annulée${NC}"
        exit 0
    fi
fi

# Restauration
echo -e "${YELLOW}Restauration en cours...${NC}"

if [ "$NEW_DB_NAME" = "$ORIGINAL_DB_NAME" ]; then
    # Restauration directe
    if zcat "$BACKUP_FILE" | mysql -u root -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null; then
        echo -e "${GREEN}✓ Restauration réussie${NC}"
    else
        echo -e "${RED}✗ Erreur lors de la restauration${NC}"
        exit 1
    fi
else
    # Restauration avec changement de nom
    zcat "$BACKUP_FILE" | sed "s/\`${ORIGINAL_DB_NAME}\`/\`${NEW_DB_NAME}\`/g" | mysql -u root -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Restauration réussie vers '${NEW_DB_NAME}'${NC}"
    else
        echo -e "${RED}✗ Erreur lors de la restauration${NC}"
        exit 1
    fi
fi

# Vérifier le nombre de tables restaurées
TABLE_COUNT=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = '${NEW_DB_NAME}';
" -sN)

echo -e "${GREEN}Tables restaurées: ${TABLE_COUNT}${NC}"
echo ""
echo -e "${GREEN}Restauration terminée avec succès !${NC}"
