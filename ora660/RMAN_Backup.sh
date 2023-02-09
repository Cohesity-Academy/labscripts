ORACLE_SID=CohesityDB1
ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
PATH=$ORACLE_HOME/bin:$PATH
RMAN=$ORACLE_HOME/bin/rman
TAG="$ORACLE_SID_"'data +%Y%m%d%H%M'
LOGDIR=/home/oracle/logs/CohesityDB1
mkdir -p $LOGDIR

export ORACLE_SID ORACLE_HOME PATH
export NLS_DATA_FORMAT='DD-MM-YYY HH24:MI:SS'
export DATE=$(date +%Y-%m-%d-%T)

LOGFILE="$LOGDIR/$(date +%Y-%m-%d-%T)_full_backup.log"

echo -e "\r\n Starting full backup of $ORACLE_SID database at $DATE. \r\n"

$RMAN target /msglog $LOGFILE << EOF

RUN {

      CONFIGURE DEVICE TYPE DISK PARALLELISM 1;
      ALLOCATE CHANNEL f1 DEVICE TYPE DISK FORMAT='/mnt/oracle-stnd-1/%d_D_%T_$u_s%s_p%p';
      BACKUP DATABASE PLUS ARCHIVELOG;
      
      }
EOF

echo - e "\r\n \r\n Full backup completed at $DATE. \r\n \r\n Job details can be found here: \$LOGFILE \r\n \r\n"
