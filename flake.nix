{
  description = "A very basic flake";
  inputs = { 
    nixpkgs.url = "github:nixos/nixpkgs?rev=14310de62cb84811b9e55f6a9931330d7c71670a";
    nixpkgs_latest.url =  "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    phps.url = "github:fossar/nix-phps";  
    shopware = {
      url = "github:shopware5/shopware?ref=95e77156a9c8e0f2c3b731d7e4835cb26921c36d";
      flake = false;
    };
  };
  outputs = { self, nixpkgs,nixpkgs_latest, flake-utils, phps, shopware }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs_latest = nixpkgs_latest.legacyPackages.${system};
        php  = phps.packages.${system}.php81;
        phpactor = pkgs_latest.phpactor;
        helix = pkgs_latest.helix;
        composer1 = phps.packages.${system}.php81.packages.composer;
        nginx = pkgs.nginx;
        starship = pkgs.starship;
        uutils-coreutils = pkgs_latest.uutils-coreutils;
        git = pkgs.git;
        fish = pkgs.git;
        zellij = pkgs_latest.zellij;
        maria = pkgs.mariadb;
        envsubst = pkgs.envsubst;
        runit = pkgs.runit;
        sd = pkgs.sd;
        dbname = "shopware";
        dbuser = "shopware";
        dbpass = "password";
        dbhost = "127.0.0.1";
        dbport = "3306";
        phpfpmport = "9123";
        shopwareversion = "5.7.18";
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            php
            nginx
            maria
            envsubst
            runit
            composer1
            sd
            phpactor 
            helix
            zellij 
            git
            uutils-coreutils
            fish
            starship             
          ];
          NGINX_PATH = nginx;
          HOSTNAME = "localhost";
          DBPASS = dbpass;
          DBUSER = dbuser;
          DBHOST = dbhost;
          DBPORT = dbport; 
          DBNAME = dbname;
          PHPFPMPORT = phpfpmport;
          shellHook = "
            if ! [ -e flake.nix ]; then
              echo \"Please execute nix develop in the directory where your flake.nix is located.\"
              exit 1
            fi
            export HOME=$PWD
            export XDG_HOME=$PWD
            export SVDIR=$HOME/.state/services
            
            #mariadb setup
            if ! [ -e $HOME/.state/mariadb/.dbcreated ]; then
              cat .state/services/mariadb/run_subst | envsubst > .state/services/mariadb/run 
              cat .state/services/mariadb/log/run_subst | envsubst > .state/services/mariadb/log/run
              mysql_install_db --datadir=./.state/mariadb/data
            fi

            #nginx setup
            if ! [ -e .state/nginx/nginx.pid ]; then
              cat .state/nginx/nginx_subst.conf | envsubst > .state/nginx/nginx.conf
              cat .state/services/nginx/run_subst | envsubst > .state/services/nginx/run 
              cat .state/services/nginx/log/run_subst | envsubst > .state/services/nginx/log/run
              touch .state/services/nginx/error.log
              touch .state/services/nginx/access.log
              touch .state/services/nginx/nginx.pid
            fi

            #php-fpm setup
            if ! [ -e .state/phpfpm/php-fpm.conf ]; then
              cat .state/phpfpm/php-fpm.conf | envsubst > .state/phpfpm/php-fpm.conf
              cat .state/services/phpfpm/run_subst | envsubst > .state/services/phpfpm/run 
              cat .state/services/phpfpm/log/run_subst | envsubst > .state/services/phpfpm/log/run
            fi

            chmod -R 755 .state
            
            #start services
            runsvdir $HOME/.state/services &
            RUNSVDIRPID=$!
            trap 'sv stop nginx && sv stop phpfpm && sv stop mariadb && kill -SIGHUP $RUNSVDIRPID' EXIT
            
            #shopware install
            if ! [ -e $HOME/shopware/recovery/install/data/install.lock ]; then 
              cp -r -u -f ${shopware}/. $HOME/shopware
              cat $HOME/.state/shopware/config.php | envsubst > $HOME/shopware/config.php
              chmod -R 755 shopware
              COMPOSER_MEMORY_LIMIT=-1 composer --no-dev install --working-dir=$HOME/shopware/recovery/common
              COMPOSER_MEMORY_LIMIT=-1 composer install --working-dir=$HOME/shopware
              mysql -S$HOME/.state/mariadb/tmp/mysql.sock -u$USER --execute 'CREATE DATABASE IF NOT EXISTS ${dbname};'
              mysql -S$HOME/.state/mariadb/tmp/mysql.sock -u$USER --execute \"CREATE USER IF NOT EXISTS '${dbuser}'@'localhost' IDENTIFIED BY '${dbpass}'\"
              mysql -S$HOME/.state/mariadb/tmp/mysql.sock -u$USER --execute \"GRANT ALL PRIVILEGES ON *.* TO '${dbuser}'@'localhost';\"
              mysql -u${dbuser} -p${dbpass} -S$HOME/.state/mariadb/tmp/mysql.sock  ${dbname} < $HOME/shopware/_sql/install/latest.sql
              mkdir -p $HOME/shopware/var/cache
              chmod -R 755 $HOME/shopware/var
              sd '___VERSION___' '${shopwareversion}' $HOME/shopware/engine/Shopware/Kernel.php
              sd '___VERSION_TEXT___' 'dev' $HOME/shopware/engine/Shopware/Kernel.php
              sd '___REVISION___' 'flake' $HOME/shopware/engine/Shopware/Kernel.php
              sd '___VERSION___' '${shopwareversion}' $HOME/shopware/recovery/install/data/version
              sd '___VERSION_TEXT___' 'dev' $HOME/shopware/recovery/install/data/version
              php $HOME/shopware/bin/console sw:migrations:migrate --mode=install
              php $HOME/shopware/bin/console sw:snippets:to:sql ./recovery/install/data/sql/snippets.sql --force --include-default-plugins --update=false
              php $HOME/shopware/bin/console sw:cache:clear
              mysqldump --quick  -u${dbuser} -p${dbpass} -S$HOME/.state/mariadb/tmp/mysql.sock ${dbname} > $HOME/shopware/recovery/install/data/sql/install.sql
              mv $HOME/shopware/config.php $HOME/shopware/configback.php
              php $HOME/shopware/recovery/install/index.php --db-host='${dbhost}' --db-port='${dbport}' --db-socket=\"$HOME/.state/mariadb/tmp/mysql.sock\" --db-password='${dbpass}' --db-user=${dbuser}  --db-name='${dbname}' --shop-currency='EUR' --admin-username='demo' --shop-host='localhost:8080' --admin-password='demo' --admin-email='your.email@shop.com' --admin-locale='de_DE' --shop-locale='de_DE' --admin-name='demo'  --no-interaction
              mv $HOME/shopware/configback.php $HOME/shopware/config.php
            fi
          ";
        };
      }  
    );
  }
