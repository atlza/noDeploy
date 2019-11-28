# noDeploy

You don't need a deploying app.    
Deploy your laravel app with a bash script.

## Getting Started

This script was tested to deploy a laravel App in a LAMP environment from a git repository and a tag version.
It assumes that you have git, npm and composer installed and working.

### Prerequisites

You need :
 - git to retrieve your code from a repo
 - npm to install dependencies and run webpack  
 - composer for php dependencies
```
Give examples
```
### What it does
 - switch current user to deploy user
 - ask for tag to deploy  
 - clone tag into destination directory  
 - install composer dependencies
 - install npm dependencies
 - run webpack
 - run artisan for DB updates and clear caches  
 - move symlink from previous release to new one (no downtime)

### Installing

Clone this repo in your ssh user home directory  

```
git clone https://github.com/atlza/noDeploy.git
```

## How to use it

This script use a deploy user, which also is member of your www-data group
This user must have the rights to access your git repository, you can use a deploy key for this.
In our case, this user is called deploy. You can change it in the deploy.sh script.

Copy the variables files
```
cp variables.example variables.prod
```
Fill the variables files with correct value.
Mainly :
```
#where you app should be deployed
deployPath="/path/to/deploy"

#your git repository
gitPath="git@github.com:user/repo.git"
```
Run the deploy script   
```
./deploy.sh prod
```
or for staging
```
./deploy.sh recette
```

## Next steps  
Add feature to remove old releases from system.

## Authors

* **Guillaume Le Roy** - *Initial work* - [Mu Studio](http://work.withmu.com)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Thanks to Charlie Etienne [Web nancy](https://web-nancy.fr/) for original script and idea
