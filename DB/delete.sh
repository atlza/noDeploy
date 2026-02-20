#!/bin/bash

#############################################
# Script de suppression de base de données MySQL
# avec sauvegarde automatique
# Usage: ./delete_db.sh nom_du_projet
#############################################

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher l'usage
usage() {
    echo -e "${YELLOW}Usage: $0 nom_du_projet [options]${NC}"
    echo ""
    echo "Options:"
    echo "  --no-backup    Supprimer sans faire de backup (non recommandé)"
    echo "  --backup-dir   Dossier pour les backups (défaut: ./backups)"
    echo ""
    echo "Exemple: $0 monapp"
    echo "Exemple: $0 monapp --backup-dir /var/backups/mysql"
    exit 1
}

# Vérifier qu'un paramètre est fourni
if [ $# -eq 0 ]; then
    echo -e "${RED}Erreur: Aucun nom de projet fourni${NC}"
    usage
fi

PROJECT_NAME=$1
DO_BACKUP=true
BACKUP_DIR="./backups"

# Parser les options
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-backup)
            DO_BACKUP=false
            shift
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Option inconnue: $1${NC}"
            usage
            ;;
    esac
done

# Validation du nom de projet
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo -e "${RED}Erreur: Le nom du projet doit contenir uniquement des lettres, chiffres et underscores${NC}"
    exit 1
fi

# Définition des variables
DB_NAME="${PROJECT_NAME}DB"
DB_USER="${PROJECT_NAME}UDB"
MYSQL_ROOT_PASSWORD=""
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_${TIMESTAMP}.sql.gz"

# Créer le dossier de backup s'il n'existe pas
if [ "$DO_BACKUP" = true ]; then
    mkdir -p "$BACKUP_DIR"
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}Erreur: Impossible de créer le dossier de backup: ${BACKUP_DIR}${NC}"
        exit 1
    fi
fi

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

# Vérifier que la base de données existe
DB_EXISTS=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${DB_NAME}';" -sN)

if [ -z "$DB_EXISTS" ]; then
    echo -e "${RED}Erreur: La base de données '${DB_NAME}' n'existe pas${NC}"
    exit 1
fi

# Vérifier que l'utilisateur existe
USER_EXISTS=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT User FROM mysql.user WHERE User = '${DB_USER}' AND Host = 'localhost';" -sN)

# Afficher les informations
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Informations sur les éléments à supprimer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "  Base de données: ${YELLOW}${DB_NAME}${NC}"
if [ -n "$USER_EXISTS" ]; then
    echo -e "  Utilisateur:     ${YELLOW}${DB_USER}@localhost${NC}"
else
    echo -e "  Utilisateur:     ${RED}Non trouvé${NC}"
fi

if [ "$DO_BACKUP" = true ]; then
    echo -e "  Backup:          ${GREEN}Oui${NC}"
    echo -e "  Fichier backup:  ${GREEN}${BACKUP_FILE}${NC}"
else
    echo -e "  Backup:          ${RED}Non${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Obtenir la taille de la base
DB_SIZE=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
    SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
    FROM information_schema.tables
    WHERE table_schema = '${DB_NAME}';
" -sN)

if [ -n "$DB_SIZE" ] && [ "$DB_SIZE" != "NULL" ]; then
    echo -e "Taille de la base: ${YELLOW}${DB_SIZE} MB${NC}"
    echo ""
fi

# Obtenir le nombre de tables
TABLE_COUNT=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = '${DB_NAME}';
" -sN)

if [ -n "$TABLE_COUNT" ] && [ "$TABLE_COUNT" -gt 0 ]; then
    echo -e "Nombre de tables: ${YELLOW}${TABLE_COUNT}${NC}"
    echo ""
fi

# Confirmation de suppression
echo -e "${RED}⚠️  ATTENTION: Cette action est IRRÉVERSIBLE !${NC}"
echo -e "${RED}⚠️  Vous allez supprimer définitivement:${NC}"
echo -e "${RED}   - La base de données '${DB_NAME}'${NC}"
if [ -n "$USER_EXISTS" ]; then
    echo -e "${RED}   - L'utilisateur '${DB_USER}@localhost'${NC}"
fi
echo ""
echo -e "${YELLOW}Pour confirmer, tapez exactement: ${RED}SUPPRIMER${NC}"
read -r CONFIRMATION

if [ "$CONFIRMATION" != "SUPPRIMER" ]; then
    echo -e "${GREEN}Opération annulée${NC}"
    exit 0
fi

echo ""

# BACKUP de la base de données
if [ "$DO_BACKUP" = true ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║              CRÉATION DU BACKUP                        ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${BLUE}Backup en cours vers: ${BACKUP_FILE}${NC}"

    # Créer le dump et le compresser
    if mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --add-drop-database \
        --databases "${DB_NAME}" 2>/dev/null | gzip > "$BACKUP_FILE"; then

        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        echo -e "${GREEN}✓ Backup créé avec succès${NC}"
        echo -e "  Fichier: ${GREEN}${BACKUP_FILE}${NC}"
        echo -e "  Taille:  ${GREEN}${BACKUP_SIZE}${NC}"

        # Créer un fichier de métadonnées
        METADATA_FILE="${BACKUP_FILE}.info"
        cat > "$METADATA_FILE" <<EOF
Backup Information
==================
Project: ${PROJECT_NAME}
Database: ${DB_NAME}
User: ${DB_USER}
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Database Size: ${DB_SIZE} MB
Table Count: ${TABLE_COUNT}
Backup File: ${BACKUP_FILE}
Backup Size: ${BACKUP_SIZE}

Restore Command:
================
gunzip < ${BACKUP_FILE} | mysql -u root -p

Or:
zcat ${BACKUP_FILE} | mysql -u root -p
EOF

        echo -e "${GREEN}✓ Fichier de métadonnées créé: ${METADATA_FILE}${NC}"
        echo ""
    else
        echo -e "${RED}✗ Erreur lors de la création du backup${NC}"
        echo -e "${RED}Abandon de la suppression pour sécurité${NC}"
        exit 1
    fi
fi

# SUPPRESSION de la base de données
echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║              SUPPRESSION EN COURS                      ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Suppression de la base de données: ${DB_NAME}${NC}"
if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" 2>/dev/null; then
    echo -e "${GREEN}✓ Base de données supprimée${NC}"
else
    echo -e "${RED}✗ Erreur lors de la suppression de la base${NC}"
    exit 1
fi

# SUPPRESSION de l'utilisateur
if [ -n "$USER_EXISTS" ]; then
    echo -e "${YELLOW}Suppression de l'utilisateur: ${DB_USER}@localhost${NC}"
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null; then
        echo -e "${GREEN}✓ Utilisateur supprimé${NC}"
    else
        echo -e "${RED}✗ Erreur lors de la suppression de l'utilisateur${NC}"
        exit 1
    fi
fi

# Flush des privilèges
echo -e "${YELLOW}Actualisation des privilèges...${NC}"
if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;" 2>/dev/null; then
    echo -e "${GREEN}✓ Privilèges actualisés${NC}"
else
    echo -e "${RED}✗ Erreur lors du flush des privilèges${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           SUPPRESSION TERMINÉE AVEC SUCCÈS             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Résumé
echo -e "${BLUE}Résumé:${NC}"
echo -e "  ${RED}✗${NC} Base supprimée:  ${DB_NAME}"
if [ -n "$USER_EXISTS" ]; then
    echo -e "  ${RED}✗${NC} User supprimé:   ${DB_USER}@localhost"
fi

if [ "$DO_BACKUP" = true ]; then
    echo ""
    echo -e "${GREEN}Backup sauvegardé:${NC}"
    echo -e "  📁 ${BACKUP_FILE}"
    echo -e "  📄 ${METADATA_FILE}"
    echo ""
    echo -e "${YELLOW}Pour restaurer cette base:${NC}"
    echo -e "  ${BLUE}gunzip < ${BACKUP_FILE} | mysql -u root -p${NC}"
    echo -e "  ${BLUE}# ou${NC}"
    echo -e "  ${BLUE}zcat ${BACKUP_FILE} | mysql -u root -p${NC}"
fi

echo ""

# Supprimer le fichier de credentials s'il existe
CREDENTIALS_FILE="${PROJECT_NAME}_credentials.txt"
if [ -f "$CREDENTIALS_FILE" ]; then
    echo -e "${YELLOW}Fichier de credentials trouvé: ${CREDENTIALS_FILE}${NC}"
    echo -e "${YELLOW}Voulez-vous le supprimer aussi? (o/N)${NC}"
    read -r DELETE_CRED
    if [[ "$DELETE_CRED" =~ ^[Oo]$ ]]; then
        rm -f "$CREDENTIALS_FILE"
        echo -e "${GREEN}✓ Fichier de credentials supprimé${NC}"
    else
        echo -e "${BLUE}Fichier de credentials conservé${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Opération terminée !${NC}"
