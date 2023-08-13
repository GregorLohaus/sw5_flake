{
  description = "A very basic flake";
  inputs = { 
    nixpkgs.url = "github:nixos/nixpkgs"; 
    flake-utils.url = "github:numtide/flake-utils";
    phps.url = "github:fossar/nix-phps";  
    shopware = {
      url = "github:shopware5/shopware?ref=d2d64507ba73d6602a8027da7bfd7a55d06aae66";
      flake = false;
    };
    nginxconfshopware = {
      url = "github:GregorLohaus/nginxshopwareconf";
      flake = false;
    };
    mariadbcnf = {
      url = "github:GregorLohaus/simplelocalmariadbconf";
      flake = false;
    };
    mariadbservice = {
      url = "github:GregorLohaus/runit_mariadb_service_for_sw5_flake";
      flake = false;
    };
    nginxservice = {
      url = "github:GregorLohaus/runit_nginx_service_for_sw5_flake";
      flake = false;
    };
    phpfpmservice = {
      url = "github:GregorLohaus/runit_phpfpm_service_for_sw5_flake";
      flake = false;
    };
    phpfpmconf = {
      url = "github:GregorLohaus/php_fpm_conf_for_sw5_flake";
      flake = false;
    };
    shopwareconf = {
      url = "github:GregorLohaus/dw5_conf_for_sw5_flake";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, flake-utils, phps, shopware, nginxconfshopware, mariadbcnf, mariadbservice, nginxservice, phpfpmconf, phpfpmservice, shopwareconf }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        php  = phps.packages.${system}.php74;
        composer1 = phps.packages.${system}.php74.packages.composer-1;
        nginx = pkgs.nginx;
        maria = pkgs.mariadb;
        envsubst = pkgs.envsubst;
        runit = pkgs.runit;
        sd = pkgs.sd;
        dbname = "shopware";
        dbuser = "shopware-user";
        dbpass = "password";
        dbhost = "127.0.0.1";
        dbport = "3306";
        shopwareversion = "567";
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
          ];
          NGINX_PATH = nginx;
          HOSTNAME = "localhost";
          DBPASS = dbpass;
          DBUSER = dbuser;
          DBHOST = dbhost;
          DBPORT = dbport; 
          DBNAME = dbname;
          shellHook = "
            #env setup
            export HOME=$PWD
            export SVDIR=$HOME/services
            mkdir -p services
            chmod -R 755 .
            
            #mariadb setup
            if ! [ -e my.cnf ]; then
              cat ${mariadbcnf}/my.cnf | envsubst > my.cnf
              mkdir -p mariadb
              mkdir -p mariadb/data
              mkdir -p mariadb/english
              mkdir -p mariadb/tmp
              touch mariadb/tmp/mysql.sock
              mkdir -p services/mariadb
              cp -r -u -f ${mariadbservice}/. services/mariadb/
              mkdir -p services/mariadb/logs
              chmod -R 777 services/mariadb
              cat services/mariadb/run_subst | envsubst > services/mariadb/run 
              cat services/mariadb/log/run_subst | envsubst > services/mariadb/log/run
              chmod -R 777 services/mariadb
              mysql_install_db --datadir=./mariadb/data
            fi
            #nginx setup
            if ! [ -e nginx.conf ]; then
              cat ${nginxconfshopware}/shopware5.conf | envsubst > nginx.conf
              cp -r -u -f ${nginxservice}/. services/
              chmod -R 777 services/nginx
              cat services/nginx_subst/run_subst | envsubst > services/nginx/run 
              cat services/nginx_subst/log/run_subst | envsubst > services/nginx/log/run
              chmod -R 777 services/nginx_subst
              rm -r services/nginx_subst
              chmod -R 777 services/nginx
              mkdir -p nginxlogs
              touch nginxlogs/error.log
              touch nginxlogs/access.log
              touch nginxlogs/nginx.pid
            fi
            #php-fpm setup
            if ! [ -e php-fpm.conf ]; then
              mkdir -p tmp
              mkdir -p phpfpmlogs 
              touch phpfpmlogs/php-fpm.log
              touch phpfpmlogs/php-fpm.pid
              chmod -R 777 phpfpmlogs
              chmod -R 777 tmp
              cat ${phpfpmconf}/php-fpm.conf | envsubst > php-fpm.conf
              cp -r -u -f ${phpfpmservice}/. services/
              chmod -R 777 services/phpfpm
              cat services/phpfpm_subst/run_subst | envsubst > services/phpfpm/run 
              cat services/phpfpm_subst/log/run_subst | envsubst > services/phpfpm/log/run
              chmod -R 777 services/phpfpm_subst
              rm -r services/phpfpm_subst
              chmod -R 777 services/phpfpm
              touch php-fpm.sock
            fi
            
            #start services
            runsvdir services &
            RUNSVDIRPID=$!
            trap 'sv stop nginx && sv stop phpfpm && sv stop mariadb && kill -SIGHUP $RUNSVDIRPID' EXIT
            
            #shopware install
            if ! [ -e recovery/install/data/install.lock ]; then 
              cp -r -u -f ${shopware}/. $HOME/
              cat ${shopwareconf}/config.php | envsubst > config.php
              chmod -R 755 recovery
              COMPOSER_MEMORY_LIMIT=-1 composer --no-dev install --working-dir=$HOME/recovery/common
              chmod -R 755 vendor
              chmod -R 755 recovery
              chmod -R 755 engine
              chmod -R 755 _sql
              chmod -R 755 web
              chmod -R 755 media  
              COMPOSER_MEMORY_LIMIT=-1 composer install
              mysql -S$HOME/mariadb/tmp/mysql.sock -u$USER --execute 'CREATE DATABASE IF NOT EXISTS ${dbname};'
              mysql -S$HOME/mariadb/tmp/mysql.sock -u$USER --execute \"CREATE USER IF NOT EXISTS '${dbuser}'@'localhost' IDENTIFIED BY '${dbpass}'\"
              mysql -S$HOME/mariadb/tmp/mysql.sock -u$USER --execute \"GRANT ALL PRIVILEGES ON *.* TO '${dbuser}'@'localhost';\"
              mysql -u${dbuser} -p${dbpass} -S$HOME/mariadb/tmp/mysql.sock  ${dbname} < _sql/install/latest.sql
              mkdir -p var/cache
              chmod -R 755 var
              sd '___VERSION___' '${shopwareversion}' engine/Shopware/Kernel.php
              sd '___VERSION_TEXT___' 'greg' engine/Shopware/Kernel.php
              sd '___REVISION___' '${shopwareversion}' engine/Shopware/Kernel.php
              sd '___VERSION___' '${shopwareversion}' recovery/install/data/version
              sd '___VERSION_TEXT___' 'greg' recovery/install/data/version
              sd 'EOD;' '' _sql/migrations/388-add-emotion-fields-position.php
              sd '\\s*\"\\);\nEOD' '\\nEOD' _sql/migrations/393-add-404-page-config-options.php
              sd '\\s*\"\\);\nEOD' '\\nEOD' _sql/migrations/469-add-404-article-page-config.php
              sd \"'Display title field', NULL\" \"'Display title field'\" _sql/migrations/741-migrate-salutation-mails.php
              sd \"'Display shop specific votes only', NULL\" \"'Display shop specific votes only'\" _sql/migrations/901-add-vote-shop-id.php
              sd \"this shop's\" \"this shops\" _sql/migrations/1434-add-href-default-selection.php
              sd \"as default.\" \"as default.'\" _sql/migrations/1434-add-href-default-selection.php
              sd \"of the meta description'\" \"of the meta description', ''\" _sql/migrations/1442-add-meta-description-config.php
              sd \"FROM s_core_config_values\" \"\" _sql/migrations/1459-change-shipping-costs-configs.php
              sd \"WHERE element_id = @elementId\\);\" \"WHERE element_id = @elementId;\" _sql/migrations/1459-change-shipping-costs-configs.php
              sd \"'notification\\\\\\'\\);'\\);[^}]*\" \"'notification\\\\\\'\);'\);\n\" _sql/migrations/1602-add-plugin-manager-privilege.php
              sd \"throw new\" \"debug_print_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS,20);\nthrow new\" engine/Library/Zend/Cache.php
              rm _sql/migrations/1632-add-acl-privilege-requirements.php
              php bin/console sw:migrations:migrate --mode=install
              php bin/console sw:snippets:to:sql ./recovery/install/data/sql/snippets.sql --force --include-default-plugins --update=false
              php bin/console sw:cache:clear
              mysqldump --quick  -u${dbuser} -p${dbpass} -S$HOME/mariadb/tmp/mysql.sock ${dbname} > recovery/install/data/sql/install.sql
              mv config.php configback.php
              php recovery/install/index.php --db-host='${dbhost}' --db-port='${dbport}' --db-socket=\"$HOME/mariadb/tmp/mysql.sock\" --db-password='${dbpass}' --db-user=${dbuser}  --db-name='${dbname}' --shop-currency='EUR' --admin-username='demo' --shop-host='localhost:8080' --admin-password='demo' --admin-email='your.email@shop.com' --admin-locale='de_DE' --shop-locale='de_DE' --admin-name='demo'  --no-interaction
              mv configback.php config.php
            fi
          ";
        };
      }  
    );
  }
