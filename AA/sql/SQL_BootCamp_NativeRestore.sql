--exec master.dbo.sp_configure 'show advanced options', 1
--RECONFIGURE
--EXEc master.dbo.sp_configure 'xp_cmdshell', 1
--RECONFIGURE
--execute xp_cmdshell 'dir \\cohesity-01.talabs.local\SQLView\*.*'

-- Step ONE, restore the database.
RESTORE DATABASE TALab FROM DISK='\\cohesity-01.talabs.local\SQLView\TALab.BAK' WITH STATS=5, NORECOVERY

-- Step TWO, restore the first log.
RESTORE LOG TALab FROM DISK='\\cohesity-01.talabs.local\SQLView\TALab01.trn' WITH STATS=5, NORECOVERY

-- Step THREE, restore the second log.
RESTORE LOG TALab FROM DISK='\\cohesity-01.talabs.local\SQLView\TALab02.trn' WITH STATS=5, RECOVERY

-- Verify the database is open and accessible, AND the table exists.
USE TALab
select * from MYLAB01
