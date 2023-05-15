-- Step ONE, Create the database.
CREATE DATABASE [CALab]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'CA-Lab_Data', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\CALab_Data.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'CA-Lab_Log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\CALab_Log.ldf' , SIZE = 8192KB , FILEGROWTH = 65536KB )


-- Step TWO, Take a FULL backup of the new database.
-- BACKUP DATABASE CALab TO DISK='CALab.BAK' WITH STATS=5
BACKUP DATABASE CALab TO DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab.BAK' WITH STATS=5

-- Step THREE, Take a Tx log backup of the database.
BACKUP LOG CALab  TO DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab01.trn'

-- Step FOUR, Change the context to the new database and create a table.
USE CALab
CREATE TABLE MYLAB01 (LABNAME varchar(50))

-- Step FIVE, Take a Tx log backup of the database.
BACKUP LOG CALab  TO DISK='\\cohesity-a.cohesitylabs.az\SQLView\CALab02.trn'
