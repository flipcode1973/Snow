USE [SnowLicenseManager]
GO

CREATE TABLE [dbo].[BSKYB_SnowSuperDeDuper_Log](
	[ComputerID] [int] NOT NULL,
	[ClientID] [int] NOT NULL,
	[HostName] [nvarchar](100) NOT NULL,
	[LastScanDate] [datetime] NOT NULL,
	[ClientVersion] [nvarchar](256) NULL,
	[ClientConfigurationName] [nvarchar](100) NULL,
	[ScanIdentifier] [nvarchar](100) NULL,
	[BiosSerialNumber] [nvarchar](100) NULL,
	[Model] [nvarchar](100) NULL,
	[DeletionRank] [int] NOT NULL,
	[DeletionDate] [datetime] NOT NULL
) ON [PRIMARY]
GO
