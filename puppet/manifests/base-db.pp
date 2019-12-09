Package {
  allow_virtual => true,
}

class { 'java' : 
  distribution  => 'jdk',
  package       => 'java-1.8.0-openjdk-devel'
}

class oracledb {
  require java
  require oracle::swap

  class { "oracle::server" :
    oracle_user  => "oracle",
    dba_group    => "dba",
    sid          => "aribadb",
    oracle_root  => "/oracle",
    password     => "oracle",
    host_name    => hiera('db_hostname'),
  }

  file {
    ["/home/oracle", "/home/oracle/db"]:
      ensure  => "directory",
      mode    => 0701,
      owner   => oracle,
      require => Class["oracle::server"];

    "/home/oracle/aribadb.sql":
      ensure  => "file",
      mode    => 0744,
      owner   => oracle,
      source  => "/vagrant/puppet/install_ariba/database/aribadb.sql",
      require => Class["oracle::server"];
  } 

  exec {
    'run-script':
      command => "bash -c 'source /etc/profile.d/ora.sh && sqlplus system/oracle @aribadb.sql'",
      cwd     => '/home/oracle',
      path    => '/usr/bin:/bin:/oracle/app/oracle/product/11.2.0/dbhome_1/bin',
      user    => oracle,
      logoutput => on_failure,
      require => File["/home/oracle/aribadb.sql"];
  }

}

include java
include oracledb
