#!/bin/bash

#environnement argument
environnement=$1
srcPath=$2

  if [ -z $environnement ]; then
    echo "Environnement is missing"
    exit -1
  elif [ -z $srcPath ]; then
    echo "SRC path is missing"
    exit -1
  elif [ $environnement != 'prod' ] && [ $environnement != 'recette' ]; then
    echo "Environnement is wrong, should be prod or recette"
    exit -1
  fi

source "${srcPath}/variables.prod"
releasesPath="${deployPath}/releases"

echo "*******************************************************"
echo "Scripts vars"
echo "*******************************************************"
echo "Deploy path : $deployPath "
echo "Releases path : $releasesPath "
echo "Config path : $configPath "
echo "Git repo : $gitPath "
echo "Release date : $releaseDate "
echo "Choosen tag: $versionTag "



#change dir to app path
cd $releasesPath
pwd

echo "*******************************************************"
echo "Cloning tag into releases directory"
echo "*******************************************************"
if [ -z $versionTag ]; then
  git clone --single-branch $gitPath $releaseDate
else
  git clone -b ${versionTag}  --single-branch $gitPath $releaseDate
fi

cd $releaseDate
pwd

# Install new composer packages
echo "*******************************************************"
echo "INSTALLING COMPOSER PACKAGES"
echo "*******************************************************"
composer install --no-dev --prefer-dist --optimize-autoloader
echo ' '

# Install new npm packages
echo "*******************************************************"
echo "INSTALLING NPM PACKAGES"
echo "*******************************************************"
npm  install
echo ' '

# Generating dist assets
echo "*******************************************************"
echo "Generating assets"
echo "*******************************************************"
npm run build
echo ' '

echo "*******************************************************"
echo "Setting .env file from .env.${environnement}"
rm -f .env
cp $srcPath/app-files/.env.${environnement} .env
echo "*******************************************************"
echo ' '

# Clear caches
echo "CLEARING CACHE"
php artisan cache:clear
echo "*******************************************************"
echo ' '

# Clear and cache routes
echo "CLEARING AND CACHE ROUTES"
php artisan route:cache
echo "*******************************************************"
echo ' '

# Clear and cache config
echo "CLEARING AND CACHE CONFIG"
php artisan config:cache
echo "*******************************************************"
echo ' '

echo "*******************************************************"
echo "Updating DB with artisan"
echo "*******************************************************"
php artisan migrate --force
echo ' '

# Clear expired password reset tokens
echo "CLEARING EXPIRED PASSWORD RESET TOKENS"
php artisan auth:clear-resets
echo "*******************************************************"
echo ' '

echo "*******************************************************"
echo "Give righ access on storage"
echo "*******************************************************"
pwd
chmod -R 0775 storage/

echo "*******************************************************"
echo "Setup environnement .htaccess"
echo "*******************************************************"
pwd
if [ -f "public/.htaccess.${environnement}" ]; then
    cp "public/.htaccess.${environnement}" public/.htaccess
    echo "Setting public/.htaccess.${environnement}"
fi

echo "*******************************************************"
echo "Creating sylinkks for shared folders"
echo "*******************************************************"
pwd
for folder in "${shared[@]}"
do
   :
   if [ ! -d "${deployPath}/shared/${folder}" ]; then
       mkdir -p "${deployPath}/shared/${folder}"
       chmod -R 0775 "${deployPath}/shared/${folder}/"
       echo " -> Creating directory: ${deployPath}/shared/${folder}"
   fi
   ln -s "${deployPath}/shared/${folder}" ${folder}
done

echo "*******************************************************"
echo "Removing old current symlink"
cd $deployPath
pwd
echo "*******************************************************"
rm current

echo "*******************************************************"
echo "Creating SymLink current"
pwd
echo "*******************************************************"
ln -s releases/${releaseDate} current

echo "*******************************************************"
echo "Removing previous versions"
pwd
echo "*******************************************************"
cd releases/
shopt -s dotglob
shopt -s nullglob
array=(*/)
for dir in "${array[@]}"; do echo "$dir"; done

# Unset shell option after use, if desired. Nullglob
# is unset by default.
shopt -u dotglob
shopt -u nullglob

#if more than 3 folders in releases we will remove olds one
arraySize=${#array[@]}

echo "Array size is ${arraySize} "
if [ "${arraySize}" -gt 3 ]; then
        echo "removing old version ${array[0]}"
        rm -rf ${array[0]}
fi

exit
