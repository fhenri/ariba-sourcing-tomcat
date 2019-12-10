class oracle::server (
  $oracle_user  = "oracle", # User to run Oracle DB
  $dba_group    = "dba", # User group for user that runs Oracle DB
  $sid          = "orcl", # SID for Oracle database
  $oracle_root  = "/oradb", # Where install database
  $password     = "password", # SYS and SYSDBA password
  $host_name    = "localhost"
) {

  # Derived parameters - do not change
  $ORACLE_USER        = "$oracle_user"
  $DBA_GROUP          = "$dba_group"
  $SID                = "$sid"
  $ORACLE_ROOT        = "$oracle_root"
  $PASSWORD           = "$password"
  $ORACLE_BASE        = "$ORACLE_ROOT/app/$ORACLE_USER"
  $ORACLE_HOME        = "$ORACLE_BASE/product/12.2.0/dbhome_1" 
  $DATA_LOCATION      = "$ORACLE_BASE/oradata"
  $INVENTORY_LOCATION = "$ORACLE_ROOT/app/oraInventory"
  $ORACLE_HOSTNAME    = "$host_name"

  package {
    ['binutils', 'compat-libcap1', 'compat-libstdc++-33', 'elfutils-libelf', 'elfutils-libelf-devel', 'gcc', 'gcc-c++', 'glibc', 'glibc-common', 'glibc-devel', 'glibc-headers', 'ksh', 'libaio', 'libaio-devel', 'libgcc', 'libstdc++', 'libstdc++-devel', 'make', 'libXext', 'libXtst', 'libX11', 'libXau', 'libxcb', 'libXi', 'sysstat', 'unixODBC', 'unixODBC-devel']:
          ensure => installed,
          notify => Exec['install-oracle'];
  }

  group{ 
    ["$DBA_GROUP", 'oinstall'] :
      ensure => present;
  } 

  user { 
    "$ORACLE_USER":
      groups  => "$DBA_GROUP",
      gid     => 'oinstall',
      #password => "$PASSWORD",
      password => '$1$0yXEC7u6$eLTh8zwo7qw3ZEEyPoS/B/',
      ensure  => present,
      shell   => "/bin/bash",
      require => Group["$DBA_GROUP", 'oinstall']
  }

  file {
    "/etc/sysctl.conf":
      owner   => root,
      mode    => 0644,
      content => template("oracledb/etc-sysctl.conf.erb");

    "/etc/security/limits.conf":
      owner   => root,
      mode    => 0644,
      content => template("oracledb/etc-security-limits.conf.erb");

    "/etc/profile.d/ora.sh":
      mode    => 0777,
      content => template("oracledb/ora.sh.erb");

    "/etc/systemd/system/oracle-rdbms.service":
      mode    => 0777,
      content => template("oracledb/oracle-rdbms.service.erb");
    
    ["$ORACLE_ROOT", "$ORACLE_ROOT/tmp"]:
      ensure  => "directory",
      owner   => "$ORACLE_USER",
      group   => "$DBA_GROUP", 
      require => Group["$DBA_GROUP"]; 

    "$ORACLE_ROOT/tmp/db_install_my.rsp":
      owner   => "$ORACLE_USER",
      content => template("oracledb/db_install_my.erb");

    "$ORACLE_ROOT/tmp/dbca.rsp":
      owner   => "$ORACLE_USER",
      content => template("oracledb/dbca.rsp.erb");

    "$ORACLE_ROOT/tmp/database":
      ensure  => 'directory',
      source  => '/vagrant/puppet/modules/oracledb/files/database',
      recurse => 'remote',
      owner   => "$ORACLE_USER",
      group   => "$DBA_GROUP", 
      require => Group["$DBA_GROUP"],
      mode    => '0755';
  }

  exec {
    "sysctl":
      command => "/usr/sbin/sysctl -p",
      cwd     => "/usr/sbin",
      require => File['/etc/sysctl.conf'],
      user    => root;

    #https://unix.stackexchange.com/questions/181782/restarting-init-without-restarting-the-system
    "reload-init":
      command => "telinit u",
      path    => ["/usr/bin/","/usr/sbin/","/bin"],
      user    => root,
      require => Exec['sysctl'];

    "pre-install-1":
      command => "/bin/sed -i 's/SELINUX=permissive$/SELINUX=disabled/g' /etc/selinux/config",
      user    => root,
      require => Exec['reload-init'];

    "install-oracle":
      command => "/bin/sh -c '$ORACLE_ROOT/tmp/database/runInstaller -silent -waitforcompletion -ignorePrereq -responseFile $ORACLE_ROOT/tmp/db_install_my.rsp'",
      cwd     => "$ORACLE_ROOT/tmp/database",
      timeout => 0,
      returns => [0, 3],
      require => [User["$ORACLE_USER"], File["$ORACLE_ROOT/tmp/database", "$ORACLE_ROOT/tmp/db_install_my.rsp", "$ORACLE_ROOT", '/etc/profile.d/ora.sh'], Exec['pre-install-1']],
      creates => "$ORACLE_BASE",
      user    => "$ORACLE_USER";

    "post-install 1":
      command => "$INVENTORY_LOCATION/orainstRoot.sh",
      user    => root,
      require => Exec['install-oracle'];

    "post-install 2":
      command => "$ORACLE_HOME/root.sh",
      user    => root,
      require => Exec['post-install 1'];

    "start-db":
      command => "/usr/bin/systemctl start oracle-rdbms",
      user    => root,
      require => [Exec['post-install 2'], File['/etc/systemd/system/oracle-rdbms.service']];

    "autostart":
      command => "/usr/bin/systemctl daemon-reexec && /usr/bin/systemctl enable oracle-rdbms",
      user    => root,
      require => [Exec['post-install 2'], File['/etc/systemd/system/oracle-rdbms.service']];

    "create-db":
      command => "/bin/sh -c 'source /etc/profile.d/ora.sh && $ORACLE_HOME/bin/dbca -silent -createDatabase -responseFile $ORACLE_ROOT/tmp/dbca.rsp'",
      cwd     => "$ORACLE_HOME/bin",
      timeout => 0,
      returns => [0, 3],
      require => Exec['reload-init', 'start-db', 'autostart'],
      creates => "$DATA_LOCATION",
      user    => "$ORACLE_USER";

    "autostart-2":
      command => "/bin/sed -i 's/:N$/:Y/g' /etc/oratab",
      user    => root,
      require => Exec['create-db'];
  }
}

class oracle::swap {
  exec {
    "create swapfile":
      # keep it the same as RAM
      command => "dd if=/dev/zero of=/swapfile bs=3M count=1024",
      path    => ["/usr/bin/","/usr/sbin/","/bin"],
      user    => root,
      creates => "/swapfile";
    "set up swapfile":
      command => "mkswap /swapfile",
      path    => ["/usr/bin/","/usr/sbin/","/bin"],
      require => Exec["create swapfile"],
      user    => root,
      unless  => "/usr/bin/file /swapfile | grep 'swap file' 2>/dev/null";
    "enable swapfile":
      command => "swapon /swapfile",
      path    => ["/usr/bin/","/usr/sbin/","/bin"],
      require => Exec["set up swapfile"],
      user    => root,
      unless  => "/bin/cat /proc/swaps | grep '^/swapfile' 2>/dev/null";
    "add swapfile entry to fstab":
      command => "echo >>/etc/fstab /swapfile swap swap defaults 0 0",
      path    => ["/usr/bin/","/usr/sbin/","/bin"],
      user    => root,
      unless  => "/bin/grep '^/swapfile' /etc/fstab 2>/dev/null";
  }

  file {
    "/swapfile":
      mode => 600,
      owner => root,
      group => root,
      require => Exec['create swapfile'];
  }
}
