CREATE DATABASE [CALab]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'CALab_Data', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\CALab_Data.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'CALab_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\CALab_Log.ldf' , SIZE = 73728KB , FILEGROWTH = 65536KB )
GO


BACKUP DATABASE CALab TO DISK='CALab.BAK' WITH STATS =5

CREATE TABLE MYLAB01 (LabName varchar(50))

BACKUP LOG CALab TO DISK='CALab01.TRN' 



RESTORE DATABASE CALab FROM DISK='CALab.BAK' WITH STATS =5, NORECOVERY

RESTORE LOG CALab FROM DISK='CALab.BAK' WITH STATS =5, RECOVERY

USE CALab

Select * from MYLAB01
