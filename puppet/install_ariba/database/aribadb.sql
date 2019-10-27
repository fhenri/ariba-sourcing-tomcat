create tablespace sourcing datafile '/home/oracle/db/sourcing.dbf' size   160M;
ALTER DATABASE DATAFILE '/home/oracle/db/sourcing.dbf' AUTOEXTEND ON NEXT 5M MAXSIZE UNLIMITED;

create tablespace sourcings1 datafile '/home/oracle/db/sourcings1.dbf' size   160M;
ALTER DATABASE DATAFILE '/home/oracle/db/sourcings1.dbf' AUTOEXTEND ON NEXT 5M MAXSIZE UNLIMITED;

create tablespace sourcings2 datafile '/home/oracle/db/sourcings2.dbf' size   160M;
ALTER DATABASE DATAFILE '/home/oracle/db/sourcings2.dbf' AUTOEXTEND ON NEXT 5M MAXSIZE UNLIMITED;



create user sourcing identified by sourcing default tablespace sourcing temporary tablespace TEMP quota unlimited on sourcing;

grant create session to sourcing;
grant create table, create any index to sourcing;
grant create view, create procedure, create cluster, create sequence, create trigger to sourcing;
GRANT EXECUTE ON CTXSYS.CTX_CLS TO sourcing;
GRANT EXECUTE ON CTXSYS.CTX_DDL TO sourcing;
GRANT EXECUTE ON CTXSYS.CTX_DOC TO sourcing;
GRANT EXECUTE ON CTXSYS.CTX_OUTPUT TO sourcing;
GRANT EXECUTE ON CTXSYS.CTX_QUERY TO sourcing;
GRANT EXECUTE ON CTXSYS.CTX_REPORT TO sourcing;
GRANT EXECUTE ON CTXSYS.CTX_THES TO sourcing;
GRANT EXECUTE ON CTXSYS.CTX_ULEXER TO sourcing;


create user sourcings1 identified by sourcings1 default tablespace sourcings1 temporary tablespace TEMP quota unlimited on sourcings1;
grant create session to sourcings1;
grant create table, create any index to sourcings1;
grant create view, create procedure, create cluster, create sequence, create trigger to sourcings1;

create user sourcings2 identified by sourcings2 default tablespace sourcings2 temporary tablespace TEMP quota unlimited on sourcings2;
grant create session to sourcings2;
grant create table, create any index to sourcings2;
grant create view, create procedure, create cluster, create sequence, create trigger to sourcings2;


CREATE OR REPLACE DIRECTORY imp_dir as '/vagrant';
GRANT read,write on directory imp_dir to sourcing;
GRANT read,write on directory imp_dir to sourcings1;
GRANT read,write on directory imp_dir to sourcings2;

EXIT;