-- Step ONE, Create the database.
CREATE DATABASE [TALab]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'TA-Lab_Data', FILENAME = N'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\DATA\TALab_Data.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'TA-Lab_Log', FILENAME = N'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\DATA\TALab_Log.ldf' , SIZE = 8192KB , FILEGROWTH = 65536KB )


-- Step TWO, Take a FULL backup of the new database.
--BACKUP DATABASE TALab TO DISK='TALab.BAK' WITH STATS=5
BACKUP DATABASE TALab TO DISK='\\cohesity-01.talabs.local\SQLView\TALab.BAK' WITH STATS=5

-- Step THREE, Take a Tx log backup of the database.
BACKUP LOG TALab  TO DISK='\\cohesity-01.talabs.local\SQLView\TALab01.trn'

-- Step FOUR, Change the context to the new database and create a table.
USE TALab
CREATE TABLE MYLAB01 (LABNAME varchar(50))

-- Step FIVE, Take a Tx log backup of the database.
BACKUP LOG TALab  TO DISK='\\cohesity-01.talabs.local\SQLView\TALab02.trn'
