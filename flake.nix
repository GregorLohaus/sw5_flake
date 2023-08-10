{
  description = "A very basic flake";
  inputs = { 
    nixpkgs.url = "github:nixos/nixpkgs"; 
    flake-utils.url = "github:numtide/flake-utils";
    phps.url = "github:fossar/nix-phps";  
    shopware = {
      url = "github:shopware5/shopware";
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
  };
  outputs = { self, nixpkgs, flake-utils, phps, shopware, nginxconfshopware, mariadbcnf, mariadbservice, nginxservice, phpfpmconf, phpfpmservice }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        php  = phps.packages.${system}.php74;
        nginx = pkgs.nginx;
        maria = pkgs.mariadb;
        envsubst = pkgs.envsubst;
        runit = pkgs.runit;
        rsync = pkgs.rsync;
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            php
            nginx
            maria
            envsubst
            runit
            rsync
          ];
          SHOPWARE_SOURCE = shopware;
          NGINX_CONF = nginxconfshopware; 
          MARIADB_CONF = mariadbcnf;
          MARIADB_SERVICE = mariadbservice;
          NGINX_SERVICE = nginxservice;
          PHPFPMCONF = phpfpmconf;
          PHPFPM_SERVICE = phpfpmservice;
          HOSTNAME = "localhost"; 
          shellHook = "
            #env setup
            export HOME=$PWD
            export SVDIR=$HOME/services
            mkdir -p services
            chmod -R 755 .
            
            #mariadb setup
            cat $MARIADB_CONF/my.cnf | envsubst > my.cnf
            mkdir -p mariadb
            mkdir -p mariadb/data
            mkdir -p mariadb/english
            mkdir -p services/mariadb
            cp -r -u -f $MARIADB_SERVICE/. services/mariadb/
            mkdir -p services/mariadb/logs
            chmod -R 777 services/mariadb
            cat services/mariadb/run_subst | envsubst > services/mariadb/run 
            cat services/mariadb/log/run_subst | envsubst > services/mariadb/log/run
            chmod -R 777 services/mariadb

            #nginx setup
            cat $NGINX_CONF/shopware5.conf | envsubst > nginx.conf
            cat $NGINX_CONF/fastcgi.conf | envsubst > fastcgi.conf
            cp -r -u -f $NGINX_SERVICE/. services/
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

            #php-fpm setup
            mkdir -p tmp
            mkdir -p phpfpmlogs 
            touch phpfpmlogs/php-fpm.log
            touch phpfpmlogs/php-fpm.pid
            chmod -R 777 phpfpmlogs
            chmod -R 777 tmp
            cat $PHPFPMCONF/php-fpm.conf | envsubst > php-fpm.conf
            cp -r -u -f $PHPFPM_SERVICE/. services/
            chmod -R 777 services/phpfpm
            cat services/phpfpm_subst/run_subst | envsubst > services/phpfpm/run 
            cat services/phpfpm_subst/log/run_subst | envsubst > services/phpfpm/log/run
            chmod -R 777 services/phpfpm_subst
            rm -r services/phpfpm_subst
            chmod -R 777 services/phpfpm
            touch php-fpm.sock
            
            #shopware setup
            cp -r -u -f $SHOPWARE_SOURCE/. $HOME/

            #start services
            # runsvdir services
          ";
        };
      }  
    );
}
