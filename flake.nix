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
  };
  outputs = { self, nixpkgs, flake-utils, phps, shopware, nginxconfshopware, mariadbcnf, mariadbservice, nginxservice }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        php  = phps.packages.${system}.php74;
        nginx = pkgs.nginx;
        maria = pkgs.mariadb;
        envsubst = pkgs.envsubst;
        runit = pkgs.runit;
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            php
            nginx
            maria
            envsubst
            runit
          ];
          SHOPWARE_SOURCE = shopware;
          NGINX_CONF = nginxconfshopware; 
          MARIADB_CONF = mariadbcnf;
          MARIADB_SERVICE = mariadbservice;
          NGINX_SERVICE = nginxservice; 
          shellHook = "
            #env setup
            export HOME=$PWD
            export SVDIR=$HOME/services
            mkdir -p services

            #mariadb setup
            cat $MARIADB_CONF/my.cnf | envsubst > my.cnf
            mkdir -p mariadb
            mkdir -p mariadb/data
            mkdir -p mariadb/english
            mkdir -p services/mariadb
            cp -r $MARIADB_SERVICE/. services/mariadb/
            mkdir services/mariadb/logs
            chmod -R 777 services/mariadb
            cat services/mariadb/run_subst | envsubst > services/mariadb/run 
            cat services/mariadb/log/run_subst | envsubst > services/mariadb/log/run
            chmod -R 777 services/mariadb

            #nginx setup
            cat $NGINX_CONF/shopware5.conf | envsubst > nginx.conf
            cat $NGINX_CONF/fastcgi.conf | envsubst > fastcgi.conf
            cp -r $NGINX_SERVICE/. services/
            chmod -R 777 services/nginx
            cat services/nginx_subst/run_subst | envsubst > services/nginx/run 
            cat services/nginx_subst/log/run_subst | envsubst > services/nginx/log/run
            chmod -R 777 services/nginx_subst
            rm -r services/nginx_subst
            chmod -R 777 services/nginx
            mkdir nginxlogs
            touch nginxlogs/error.log
            touch nginxlogs/nginx.pid
            
            #shopware setup
            cp -r $SHOPWARE_SOURCE/. $HOME/

            #start services
            runsvdir services
          ";
        };
      }  
    );
}
