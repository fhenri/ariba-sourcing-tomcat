$ARIBA_HOST     = hiera('ariba_hostname')
$ARIBA_DB_HOST  = hiera('db_hostname')
$ARIBA_DB_IP    = hiera('host_db_address')
$ARIBA_VERSION  = hiera('ariba_version')
$ARIBA_SP       = hiera('ariba_sp')
$ARIBA_USER     = hiera('ariba_user')

$TOMCAT_VERSION = hiera('tomcat_version')

$ARIBA_ROOT        = "/home/$ARIBA_USER"
$ARIBA_INST        = "$ARIBA_ROOT/install_sources"
$ARIBA_CONF        = "$ARIBA_INST/conf"
$ARIBA_BASE        = "$ARIBA_ROOT/Sourcing"
$ARIBA_SERVER      = "$ARIBA_BASE/Server"

$AES_INST_UPSTREAM = "$ARIBA_INST/Upstream-$ARIBA_VERSION"
$AES_INST_PROPS    = "$ARIBA_INST/properties"

Package {
  allow_virtual => true,
}

class { 'apache': }

#necessary for ariba installation from command line
class { 'perl': }

class { 'java' : 
  distribution  => 'jdk',
  package       => 'java-1.8.0-openjdk-devel'
}

class { 'tomcat':
  user          => 'ariba',
  manage_user   => false,
  group         => 'ariba',
}

class tomcatapp { 
  require java
  require tomcat

  file { 
    "/opt/$TOMCAT_VERSION":
      ensure  => 'directory',
      mode    => 0777;

    "/opt/$TOMCAT_VERSION/asmserver1":
      ensure  => 'directory',
      mode    => 0777;

    "/opt/$TOMCAT_VERSION/asmserver2":
      ensure  => 'directory',
      mode    => 0777;
  }

  if $TOMCAT_VERSION == 'tomcat7' {
    $sourceURL = "$ARIBA_INST/tomcat/apache-tomcat-7.0.96.tar.gz"
  }
  elsif $TOMCAT_VERSION == 'tomcat8' {
    $sourceURL = "$ARIBA_INST/tomcat/apache-tomcat-8.5.16.tar.gz"
  }
  else {
    warning("unknown tomcat version $TOMCAT_VERSION")
  }

  tomcat::instance { "$TOMCAT_VERSION-asmserver1":
    install_from_source => true,
    catalina_base       => "/opt/$TOMCAT_VERSION/asmserver1",
    catalina_home       => "/opt/$TOMCAT_VERSION/asmserver1",
    source_url          => "$sourceURL",
    require             => [
      File["/opt/$TOMCAT_VERSION/asmserver1"]
    ]
  }

  tomcat::instance { "$TOMCAT_VERSION-asmserver2":
    install_from_source => true,
    catalina_base       => "/opt/$TOMCAT_VERSION/asmserver2",
    catalina_home       => "/opt/$TOMCAT_VERSION/asmserver2",
    source_url          => "$sourceURL",
    require             => [
      File["/opt/$TOMCAT_VERSION/asmserver2"]
    ]
  }
}

class ariba {
  require perl
  require java
  require tomcatapp

  package {
    ['libXext.i686', 'glibc.i686' , 'dejavu*', 
     'unixODBC', 'Xvfb', 'lsof', 'unzip', 'zip', 
     'mutt', 'ant', 'git']:
      ensure => installed;
  }

#  user { 
#    $ARIBA_USER:
#      ensure  => present,
#      shell   => '/bin/bash'
#  }

  File {
    ensure  => 'file',
    owner   => $ARIBA_USER,
  }

  # check if we have jrebel directory - then copy
  $jrebel = file("$ARIBA_INST/jrebel/jrebel.jar",'/dev/null')
  if($jrebel != '') {
      file { "$ARIBA_ROOT/jrebel":
        ensure  => 'directory',
        source  => "$ARIBA_INST/jrebel",
        recurse => 'remote',
        purge   => true,
        replace => "yes";
      }
  }

  file {
    "$ARIBA_ROOT":
      ensure => "directory",
      mode   => 0701; 

    "$ARIBA_CONF":
      ensure => "directory";

    "$ARIBA_ROOT/.Xauthority":
      ensure => present,
      content => '';

    "$ARIBA_CONF/script.table":
      require => File["$ARIBA_CONF"],
      source  => "$AES_INST_PROPS/script.table";

    "$ARIBA_CONF/ParametersFix.table.merge":
      require => File["$ARIBA_CONF"],
      content => template("$AES_INST_PROPS/Parameters.table.merge.erb");

    "$ARIBA_CONF/sp-upstream-installer.properties":
      require => File["$ARIBA_CONF"],
      content => template("$AES_INST_PROPS/sp-upstream-installer.properties.erb");

    "$ARIBA_CONF/upstream-installer.properties":
      require => File["$ARIBA_CONF"],
      content => template("$AES_INST_PROPS/upstream-installer.properties.erb");

    "$ARIBA_ROOT/shared":
      ensure  => 'directory',
      source  => "$AES_INST_UPSTREAM/shared",
      recurse => 'remote',
      purge   => true,
      replace => "no",
      owner   => 'ariba',
      mode    => 0755;

    "$ARIBA_ROOT/shared/config/asmshared/AppInfo.xml":
      require => File["$ARIBA_ROOT/shared"],
      content => template("$AES_INST_PROPS/AppInfo.xml.erb");

    "/etc":
      ensure  => 'directory',
      source  => "$ARIBA_INST/etc",
      recurse => 'remote',
      purge   => true,
      replace => "no",
      owner   => 'root',
      mode    => 0755;

    "/etc/environment":
      source  => "$ARIBA_INST/etc/environment",
      replace => "yes",
      owner   => 'root',
      mode    => 0644;

    "/etc/httpd/conf.d/ariba.conf":
      mode    => 0777,
      owner   => root,
      content => template("$ARIBA_INST/properties/ariba.conf.tomcat.proxy.erb"),
#      content => template("$ARIBA_INST/properties/ariba.conf.tomcat.modjk.erb"),
      notify => Class['Apache::Service'];

#    "/etc/httpd/conf.d/workers.properties":
#      mode    => 0777,
#      owner   => root,
#      content => template("$ARIBA_INST/properties/workers.properties.erb");

#    "/etc/httpd/modules/mod_jk.so":
#      mode    => 0777,
#      owner   => root,
#      source  => "$ARIBA_INST/tomcat/mod_jk.so";

    "$ARIBA_SERVER/classes/js.jar":
      require => Exec['install_ariba'],
      source  => "$ARIBA_INST/tomcat/javascript-1.7.2.jar";
  }

  exec {
    "autostart_xvfb":  
      command => "/sbin/chkconfig --level 2345 ariba-Xvfb on",
      user    => root,
      require =>File['/etc'];

    "install_ariba" :
      environment => ["INSTALL_DIR=$ARIBA_INST"],
      command => "$ARIBA_INST/install-ariba.sh aes. $ARIBA_VERSION $ARIBA_SP",
      cwd     => "$ARIBA_INST",
      timeout => 0,
      returns => [0, 1],
      require => [
        Exec['autostart_xvfb'],
        File[
          "$ARIBA_CONF/sp-upstream-installer.properties",
          "$ARIBA_CONF/upstream-installer.properties",
          "$ARIBA_CONF/script.table",
          "$ARIBA_CONF/ParametersFix.table.merge"
        ]
      ],
      creates => "$ARIBA_BASE",
      user    => "$ARIBA_USER";

    "deploy_tomcat_asmserver1" :
      environment => ["CATALINA_HOME=/opt/$TOMCAT_VERSION/asmserver1"],
      command => "$ARIBA_SERVER/bin/certifyTomcatMigration -dsrm && $ARIBA_SERVER/bin/certifyTomcatMigration -j2ee tomcat",
      cwd     => "$ARIBA_SERVER",
      timeout => 0,
      returns => [0, 1],
      require => [
        Exec['install_ariba']
      ],
      user    => "$ARIBA_USER";

    "deploy_tomcat_asmserver2" :
      environment => ["CATALINA_HOME=/opt/$TOMCAT_VERSION/asmserver2"],
      command => "$ARIBA_SERVER/bin/certifyTomcatMigration -dsrm  && $ARIBA_SERVER/bin/certifyTomcatMigration -j2ee tomcat",
      cwd     => "$ARIBA_SERVER",
      timeout => 0,
      returns => [0, 1],
      require => [
        Exec['install_ariba']
      ],
      user    => "$ARIBA_USER";
      # update in port number still need to be done as it will put default port
  }

  ## clean files so we can rerun the install
  $files = [
      "$ARIBA_CONF/sp-upstream-installer.properties",
      "$ARIBA_CONF/upstream-installer.properties",
      "$ARIBA_CONF/upstream-installer.properties.orig",
      "$ARIBA_CONF/script.table",
    ]

  ## using file / absent does not work as it will be reduplicate declaration
  #file { $files:
  #  ensure  => absent,
  #  require => [Exec['install_ariba'], File['/etc']];
  #}
  define cleanfile {
    exec { "rm ${name}":
      path    => ['/usr/bin','/usr/sbin','/bin','/sbin'],
    }
  }
  cleanfile { $files: 
      require => [Exec['install_ariba']];
  }
}

include apache
include perl
include ariba
include java
include tomcatapp
