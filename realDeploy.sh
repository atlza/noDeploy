#!/bin/bash
set -e

step() { echo; echo "==> $1"; }

# Arguments
environnement=$1
srcPath=$2

if [ -z "$environnement" ]; then
    echo "Environnement is missing"
    exit 1
elif [ -z "$srcPath" ]; then
    echo "SRC path is missing"
    exit 1
elif [ "$environnement" != 'prod' ] && [ "$environnement" != 'recette' ]; then
    echo "Environnement is wrong, should be prod or recette"
    exit 1
fi

source "${srcPath}/variables.${environnement}"
releasesPath="${deployPath}/releases"

if [ -z "${versionTag+x}" ]; then
    echo "Which tag shall we deploy? - empty for master branch -"
    read versionTag
fi

step "Deploy config"
echo "  Deploy path  : $deployPath"
echo "  Releases path: $releasesPath"
echo "  Config path  : $configPath"
echo "  Git repo     : $gitPath"
echo "  Release date : $releaseDate"
echo "  Tag          : ${versionTag:-master}"

step "Cloning repository"
cd "$releasesPath"
if [ -z "$versionTag" ]; then
    git clone --single-branch "$gitPath" "$releaseDate"
else
    git clone -b "${versionTag}" --single-branch "$gitPath" "$releaseDate"
fi
cd "$releaseDate"

step "Installing composer packages"
composer install --no-dev --prefer-dist --optimize-autoloader

step "Installing npm packages"
npm install

step "Building assets"
npm run build

step "Setting .env from .env.${environnement}"
rm -f .env
cp "$srcPath/app-files/.env.${environnement}" .env

if [ "${isLaravel}" = "true" ]; then
    step "Clearing cache"
    php artisan cache:clear

    step "Caching routes"
    php artisan route:cache

    step "Caching config"
    php artisan config:cache

    step "Linking storage"
    php artisan storage:link

    step "Running migrations"
    php artisan migrate --force

    step "Clearing expired password reset tokens"
    php artisan auth:clear-resets
fi

step "Setting permissions on storage"
chmod -R 0775 storage/

step "Setting up .htaccess"
if [ -f "public/.htaccess.${environnement}" ]; then
    cp "public/.htaccess.${environnement}" public/.htaccess
    echo "  Using public/.htaccess.${environnement}"
fi

step "Creating symlinks for shared folders"
for folder in "${shared[@]}"; do
    if [ ! -d "${deployPath}/shared/${folder}" ]; then
        mkdir -p "${deployPath}/shared/${folder}"
        chmod -R 0775 "${deployPath}/shared/${folder}/"
        echo "  -> Created: ${deployPath}/shared/${folder}"
    fi
    ln -s "${deployPath}/shared/${folder}" "${folder}"
done

step "Switching current symlink to new release"
cd "$deployPath"
rm -f current
ln -s "releases/${releaseDate}" current
echo "  current -> releases/${releaseDate}"

step "Removing old releases"
cd releases/
shopt -s dotglob nullglob
array=(*/)
shopt -u dotglob nullglob

echo "  Releases found: ${#array[@]} (keeping ${oldVersions})"
while [ "${#array[@]}" -gt "${oldVersions}" ]; do
    echo "  -> Removing ${array[0]}"
    rm -rf "${array[0]}"
    array=("${array[@]:1}")
done

echo
echo "==> Deploy complete: releases/${releaseDate}"
