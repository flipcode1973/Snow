CREATE PROCEDURE [dbo].[SnowSuperDeDuper]
(
    @ProcessingHourStart SMALLINT = 0, 
    @ProcessingHourEnd SMALLINT = 23
)
AS
/*********************************************************************************************************
Name :		SnowSuperDeDuper
Summary	:	Identifies duplicates in Snow License Manager (tblComputer) and removes all the oldest records
            leaving the most recent. Links to SnowInventory to removed related records from there.
Notes	:   - Logs deletions to table dbo.SnowSuperDeDuper_Log
            - Optional 'processing hours', set paramters @ProcessingHourStart and @ProcessingHourEnd
              to limit when deletion will be allowed.
*********************************************************************************************************/
BEGIN

    SET NOCOUNT ON
       
    DECLARE @ComputerID INT = 0
    DECLARE @ClientID INT = 0
    DECLARE @ClientXMLDelete NVARCHAR(100)
    DECLARE @HostName NVARCHAR(100)
    DECLARE @LastScanDate DATETIME
	  DECLARE @ClientVersion NVARCHAR(256)
    DECLARE @ClientConfigurationName NVARCHAR(100)
    DECLARE @ScanIdentifier NVARCHAR(100)
    DECLARE @BiosSerialNumber NVARCHAR(100)
    DECLARE @Model NVARCHAR(100) 
    DECLARE @DeletionRank INT
	
    /* Query to identify what records to delete */
    DECLARE curDataToDelete CURSOR FOR 
        SELECT  c.ComputerID,
                ISNULL(m.ClientID, 0) As ClientID,
                '<item id="' + CAST(ISNULL(m.ClientID, 0) AS VARCHAR(10)) + '"/>'  AS ClientXMLDelete,
                c.HostName,
                c.LastScanDate,
                c.ClientVersion,
                c.ClientConfigurationName,
                c.ScanIdentifier,
                c.BiosSerialNumber,
                c.Model,
                c2.rnk
        FROM    SnowLicenseManager.dbo.tblComputer c  INNER JOIN
                (SELECT ComputerID, HostName, LastScanDate, BiosSerialNumber, 
                    RANK() OVER(PARTITION BY Hostname ORDER BY LastScanDate DESC) As rnk 
                    FROM SnowLicenseManager.dbo.tblComputer) c2 ON c.ComputerID = c2.ComputerID
        LEFT JOIN SnowLicenseManager.inv.tblComputerInvSlmMap m ON m.ComputerID = c.ComputerID
        LEFT JOIN SnowInventory.inv.DataClientView2 d on m.ClientId = d.ClientId
        WHERE   c2.rnk > 1
        ORDER  BY c.Hostname ASC, c.LastScanDate DESC

    /* Loop round results, deleting each on from SnowLicenseManager and SnowInventory */
    OPEN curDataToDelete;
    FETCH NEXT FROM curDataToDelete INTO @ComputerID, @ClientID, @ClientXMLDelete, @HostName, @LastScanDate, @ClientVersion, @ClientConfigurationName, @ScanIdentifier, @BiosSerialNumber, @Model, @DeletionRank
    WHILE (@@FETCH_STATUS = 0 AND DATEPART(HOUR, GETDATE()) BETWEEN @ProcessingHourStart AND @ProcessingHourEnd)
    BEGIN
        PRINT 'Deleting ComputerID:' + CAST(@ComputerID AS VARCHAR(10)) + ' from SLM';
        EXEC SnowLicenseManager.dbo.ComputerDelete 1, @ComputerID, 'Snow Super Deduper', 1

        PRINT 'Deleting ClientID:' + CAST(@ClientID AS VARCHAR(10)) + ' from Inventory';
        EXEC SnowInventory.inv.DeleteClients @ClientXMLDelete

        /* Log the deletion */
        INSERT INTO dbo.SnowSuperDeDuper_Log 
            (ComputerID, ClientID, HostName, LastScanDate, ClientVersion, ClientConfigurationName, ScanIdentifier, BiosSerialNumber, Model, DeletionRank, DeletionDate)
        VALUES
            (@ComputerID, @ClientID, @HostName, @LastScanDate, @ClientVersion, @ClientConfigurationName, @ScanIdentifier, @BiosSerialNumber, @Model, @DeletionRank, GETDATE())
            	  
        FETCH NEXT FROM curDataToDelete INTO @ComputerID, @ClientID, @ClientXMLDelete, @HostName, @LastScanDate, @ClientVersion, @ClientConfigurationName, @ScanIdentifier, @BiosSerialNumber, @Model, @DeletionRank
    END
    
    CLOSE curDataToDelete
    DEALLOCATE curDataToDelete

END
