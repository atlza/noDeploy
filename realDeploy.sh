#!/bin/bash

#environnement argument
environnement=$1

echo $#
echo environnement

  if [ -z $environnement ]; then
    echo "Environnement is missing"
    exit -1
  else
    if [ $environnement != "prod"] && [$environnement != "recette"]; then
      echo "Environnement is wrong, should be prod or recette"
     exit -1
    fi
  fi

source 'variables.prod'

echo "*******************************************************"
echo "Scripts vars"
echo "*******************************************************"
echo "Deploy path : $deployPath "
echo "Git repo : $gitPath "
echo "Release date : $releaseDate "
echo "Choosen tag: $versionTag "


#change dir to app path
cd $deployPath
pwd

echo "*******************************************************"
echo "Cloning tag into releases directory"
echo "*******************************************************"
git clone -b ${versionTag}  --single-branch $gitPath $releaseDate


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
npm run prod
echo ' '

echo "*******************************************************"
echo "MIGRATING DATABASE"
php artisan migrate --force
echo "*******************************************************"
echo ' '

echo "*******************************************************"
echo "USING correct .env file"
echo "*******************************************************"
echo ' '

# Clear caches
echo "CLEARING CACHE"
php artisan cache:clear
echo "*******************************************************"
echo ' '

# Clear expired password reset tokens
echo "CLEARING EXPIRED PASSWORD RESET TOKENS"
php artisan auth:clear-resets
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

rm -f .env
cp .env.prod .env

echo "*******************************************************"
echo "Updating DB with artisan"
echo "*******************************************************"
php artisan migrate --force
echo ' '

rm -f .env
cp .env.prod .env

echo "*******************************************************"
echo "Removing old current symlink"
echo "*******************************************************"
pwd
cd ../../
rm current

echo "*******************************************************"
echo "Creating SymLink current"
pwd
echo "*******************************************************"
ln -s releases/${releaseDate} current

exit
