#!/bin/bash

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# Replace "username" by your username
ME="deploy"

#environnement argument
environnement=$1

echo "*******************************************************"
echo "Launching deploy as ${ME} in $environnement "
echo "*******************************************************"

if [ -z $environnement ]; then
    echo "Environnement is missing"
    exit -1
elif [ $environnement != 'prod' ] && [ $environnement != 'recette' ]; then
    echo "Environnement is wrong, should be prod or recette"
    exit -1
fi

#sudo deploy
sudo -i -u $ME bash -c "${PWD}/realDeploy.sh $environnement $PWD "
