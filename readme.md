# noDeploy
Deploy your PHP app with a bash script.

## Getting Started

This script deploys a PHP app (including Laravel) in a LAMP environment from a git repository and a tag version.
It assumes that you have git, npm and composer installed and working.

### Prerequisites

You will need :
 - git to retrieve your code from a repo
 - npm to install dependencies and run build assets
 - composer for php dependencies
 - MySQL/MariaDB for the initial database setup

### What it does
 - switch current user to deploy user
 - create the database on first run (via DB/create.sh)
 - ask for tag to deploy (or use master branch)
 - clone tag into a timestamped releases directory
 - install composer dependencies
 - install npm dependencies
 - build assets (npm run build)
 - copy the `.env` file from `app-files/`
 - run artisan commands for DB migrations and cache clearing (Laravel only)
 - set permissions on storage directory
 - setup environment-specific `.htaccess`
 - create symlinks for shared folders (e.g. storage)
 - move symlink `current` from previous release to new one (no downtime)
 - remove old releases beyond the configured limit

### Directory structure

After deployment, the deploy path will look like this:

```
deployPath/
├── current -> releases/20240101120000   (symlink)
├── releases/
│   ├── 20240101120000/
│   └── 20240102130000/
└── shared/
    └── storage/
```

### Installing

Clone this repo in your ssh user home directory.
Give the current user permission to execute both `deploy.sh` and `realDeploy.sh`.
Also give others users execute rights on `realDeploy.sh` so the deploy user can run it.

```
git clone https://github.com/atlza/noDeploy.git
```

```
chmod +x deploy.sh realDeploy.sh
chmod o+x realDeploy.sh
```

## How to use it

This script uses a deploy user, which must also be a member of your `www-data` group.
This user must have access to your git repository — you can use a deploy key for this.

### 1. Copy and fill the variables file

```
cp variables.example variables.prod
```

Fill in the values:

```bash
# Which user should deploy the app
ME="username"

# The name of your project, used for database setup
PROJECT="myProject"

# Where your app should be deployed
deployPath="/path/to/deploy/prod"

# Your git repository
gitPath="git@github.com:user/repo.git"

# Set to true if the project is a Laravel project (enables php artisan commands)
isLaravel=true

# Number of old versions to keep for rollback (1 = keep only the new one)
oldVersions=3

# Shared folders to symlink (without trailing /)
shared[0]="storage"
```

For staging, create a separate file:
```
cp variables.example variables.recette
```

### 2. Add your environment files

Place your `.env` files in the `app-files/` directory (not tracked by git):

```
app-files/
├── .env.prod
└── .env.recette
```

### 3. Run the deploy script

```
./deploy.sh prod
```

or for staging:

```
./deploy.sh recette
```

### Pinning a version

To always deploy a specific tag without being prompted, set `versionTag` in your variables file:

```bash
versionTag='1.2.3'
```

Leave it commented out to be asked at each deployment.

## Next steps
- Rollback command to restore a previous release
- Slack/email notification on deploy success or failure

## Authors

* **Guillaume Le Roy** [Mu Studio](http://work.withmu.com)


## License

This project is licensed under the MIT License - see the [LICENSE.md](license.md) file for details

## Acknowledgments

* Thanks to Charlie Etienne [Web nancy](https://web-nancy.fr/) for original script and idea
