ORACLE_SID=XE
ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
PATH=$ORACLE_HOME/bin:$PATH
RMAN=$ORACLE_HOME/bin/rman
export ORACLE_SID ORACLE_HOME PATH

LOGFILE="$LOGDIR/$(date +%Y-%m-%d-%T)_full_backup.log"

echo -e "\r\n Starting restore of $ORACLE_SID database at $DATE. \r\n"

$RMAN target / nocatalog $LOGFILE << EOF

RUN {
      shutdown;
      startup mount;
      restore database;
      recover database;
      alter database open;
      }
EOF

echo - e "\r\n \r\n Restore completed at $DATE. \r\n \r\n Job details can be found here: \$LOGFILE \r\n \r\n"
