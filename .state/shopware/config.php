<?php
return [
    'db' => [
        'username' => '$DBUSER',
        'password' => '$DBPASS',
        'dbname' => '$DBNAME',
        'host' => '$DBHOST',
        'port' => '$DBPORT',
        'socket' => '$HOME/.state/mariadb/tmp/mysql.sock'
    ],

    'front' => [
        'throwExceptions' => true,
        'showException' => true
    ],

    'phpsettings' => [
        'display_errors' => 1
    ],

    'template' => [
        'forceCompile' => true
    ],

    'csrfProtection' => [
        'frontend' => true,
        'backend' => true
    ],

    'httpcache' => [
        'debug' => true
    ]
];
