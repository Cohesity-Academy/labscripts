ORACLE_SID=XE
ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
PATH=$ORACLE_HOME/bin:$PATH
RMAN=$ORACLE_HOME/bin/rman
export ORACLE_SID ORACLE_HOME PATH


$RMAN target / nocatalog $LOGFILE << EOF

RUN {
      shutdown;
      startup mount;
      restore database;
      recover database;
      alter database open;
      }
EOF



