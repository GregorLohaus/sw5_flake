{
  description = "A very basic flake";
  inputs = { 
    nixpkgs.url = "github:nixos/nixpkgs?rev=14310de62cb84811b9e55f6a9931330d7c71670a";
    nixpkgs_latest.url =  "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    phps.url = "github:fossar/nix-phps?rev=5d9c6911fa10b5dcc8b064db92073b20398514db";  
    shopware = {
      url = "github:shopware5/shopware?ref=v5.6.7";
      flake = false;
    };
  };
  outputs = { self, nixpkgs,nixpkgs_latest, flake-utils, phps, shopware }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs_latest = nixpkgs_latest.legacyPackages.${system};
        php  = phps.packages.${system}.php74;
        phpactor = pkgs_latest.phpactor;
        helix = pkgs_latest.helix;
        composer = phps.packages.${system}.php74.packages.composer-1;
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
        shopwareversion = "5.6.7";
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            php
            nginx
            maria
            envsubst
            runit
            composer
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
              cat .state/mariadb/my_subst.cnf | envsubst > .state/mariadb/my.cnf
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
              cat .state/phpfpm/php-fpm_subst.conf | envsubst > .state/phpfpm/php-fpm.conf
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
              chmod -R 755 shopware
              cat $HOME/.state/shopware/config.php | envsubst > $HOME/shopware/config.php
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
              sd '___REVISION___' 'e496b98' $HOME/shopware/engine/Shopware/Kernel.php
              sd '___VERSION___' '${shopwareversion}' $HOME/shopware/recovery/install/data/version
              sd '___VERSION_TEXT___' 'dev' $HOME/shopware/recovery/install/data/version
              rm $HOME/shopware/_sql/migrations/1649-add-cookie-consent-manager-site.php
              rm $HOME/shopware/_sql/migrations/1639-add-review-widget.php
              rm $HOME/shopware/_sql/migrations/1632-add-acl-privilege-requirements.php
              rm $HOME/shopware/_sql/migrations/1609-allow-longer-customergroup-keys.php
              rm $HOME/shopware/_sql/migrations/1459-change-shipping-costs-configs.php
              rm $HOME/shopware/_sql/migrations/1442-add-meta-description-config.php
              rm $HOME/shopware/_sql/migrations/1438-add-bi-widgets.php
              rm $HOME/shopware/_sql/migrations/1434-add-href-default-selection.php
              rm $HOME/shopware/_sql/migrations/1408-proportional-tax-calculation.php
              rm $HOME/shopware/_sql/migrations/1201-remove-secure-shop-config.php
              rm $HOME/shopware/_sql/migrations/901-add-vote-shop-id.php
              rm $HOME/shopware/_sql/migrations/797-remove-salutation-snippets.php
              rm $HOME/shopware/_sql/migrations/795-remove-salutation-snippets.php
              rm $HOME/shopware/_sql/migrations/750-migrate-article-details-base-price.php
              rm $HOME/shopware/_sql/migrations/746-migrate-shipping.php
              rm $HOME/shopware/_sql/migrations/745-add-title-user-shipping.php
              rm $HOME/shopware/_sql/migrations/744-add-title-order-shipping.php
              rm $HOME/shopware/_sql/migrations/743-add-title-order-billing.php
              rm $HOME/shopware/_sql/migrations/742-add-title-user-billing.php
              rm $HOME/shopware/_sql/migrations/741-migrate-salutation-mails.php
              rm $HOME/shopware/_sql/migrations/735-migrate-old-emotion-relation.php
              rm $HOME/shopware/_sql/migrations/731-remove-emotion-grids.php
              rm $HOME/shopware/_sql/migrations/708-attribute-administration.php
              rm $HOME/shopware/_sql/migrations/705-rename-category-template-column.php
              rm $HOME/shopware/_sql/migrations/701-remove-emotion-backend-options.php
              rm $HOME/shopware/_sql/migrations/700-remove-filter-values.php
              rm $HOME/shopware/_sql/migrations/495-fix-shopping-worlds-grid.php
              rm $HOME/shopware/_sql/migrations/483-set-device-type-nullable.php
              rm $HOME/shopware/_sql/migrations/469-add-404-article-page-config.php
              rm $HOME/shopware/_sql/migrations/422-add-plugin-categories.php
              rm $HOME/shopware/_sql/migrations/416-remove-dummy-plugins.php
              rm $HOME/shopware/_sql/migrations/419-extract-acl-service.php
              rm $HOME/shopware/_sql/migrations/410-add-emotion-fields.php
              rm $HOME/shopware/_sql/migrations/393-add-404-page-config-options.php
              rm $HOME/shopware/_sql/migrations/390-add-device-column.php
              rm $HOME/shopware/_sql/migrations/388-add-emotion-fields-position.php
              rm shopware/_sql/migrations/773-add-library-component-fields.php
              rm shopware/_sql/migrations/772-allow-label-nullable.php
              rm shopware/_sql/migrations/763-add-attributes-read-acl.php
              rm shopware/_sql/migrations/757-add-array-store-field.php
              rm shopware/_sql/migrations/740-new-border-setting-for-emotion-widgets.php
              rm shopware/_sql/migrations/736-add-article-widget-categorie-selection.php
              rm shopware/_sql/migrations/707-add-new-emotion-link-target-field.php
              rm shopware/_sql/migrations/703-activate-html-code-widget-by-default.php
              rm shopware/_sql/migrations/603-add-product-streams.php
              rm shopware/_sql/migrations/478-add-emotion-banner-title-attr.php
              rm shopware/_sql/migrations/442-add-option-to-disable-styling-emotions.php
              rm shopware/_sql/migrations/436-update-html5-video-fields.php
              rm shopware/_sql/migrations/434-add-emotion-components.php
              rm shopware/_sql/migrations/433-emotion-device-column-as-varchar.php
              rm shopware/_sql/migrations/778-add-attribtue-default-value.php
              rm shopware/_sql/migrations/1652-enforce-unique-attributes.php
              rm shopware/_sql/migrations/1643-allow-attributes-readonly.php
              rm shopware/_sql/migrations/1624-add-content-type-to-emotion.php
              rm shopware/_sql/migrations/919-change-article-emotion-elements.php
              php $HOME/shopware/bin/console sw:migrations:migrate --mode=install
              php $HOME/shopware/bin/console sw:snippets:to:sql ./shopware/recovery/install/data/sql/snippets.sql --force --include-default-plugins --update=false
              php $HOME/shopware/bin/console sw:cache:clear
              mysqldump --quick  -u${dbuser} -p${dbpass} -S$HOME/.state/mariadb/tmp/mysql.sock ${dbname} > $HOME/shopware/recovery/install/data/sql/install.sql
              mv $HOME/shopware/config.php $HOME/shopware/configback.php
              php $HOME/shopware/recovery/install/index.php --db-host='${dbhost}' --db-port='${dbport}' --db-socket=\"$HOME/.state/mariadb/tmp/mysql.sock\" --db-password='${dbpass}' --db-user=${dbuser}  --db-name='${dbname}' --shop-currency='EUR' --admin-username='demo' --shop-host='localhost:8080' --admin-password='demo' --admin-email='your.email@shop.com' --admin-locale='de_DE' --shop-locale='de_DE' --admin-name='demo'  --no-interaction
              mv $HOME/shopware/configback.php $HOME/shopware/config.php
            fi
            zellij
          ";
        };
      }  
    );
  }
