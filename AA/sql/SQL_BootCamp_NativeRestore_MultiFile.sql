RESTORE DATABASE CALab FROM 
DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab_01.BAK',
DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab_02.BAK',
DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab_03.BAK',
DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab_04.BAK'
WITH STATS=5, RECOVERY
