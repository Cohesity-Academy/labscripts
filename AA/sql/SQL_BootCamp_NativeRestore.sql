--exec master.dbo.sp_configure 'show advanced options', 1
--RECONFIGURE
--EXEc master.dbo.sp_configure 'xp_cmdshell', 1
--RECONFIGURE
--execute xp_cmdshell 'dir \\cohesity-a.cohesitylabs.az\SQLView\*.*'

-- Step ONE, restore the database.
RESTORE DATABASE CALab FROM DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab.BAK' WITH STATS=5, NORECOVERY

-- Step TWO, restore the first log.
RESTORE LOG CALab FROM DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab01.trn' WITH STATS=5, NORECOVERY

-- Step THREE, restore the second log.
RESTORE LOG CALab FROM DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab02.trn' WITH STATS=5, RECOVERY

-- Verify the database is open and accessible, AND the table exists.
USE CALab
select * from MYLAB01
