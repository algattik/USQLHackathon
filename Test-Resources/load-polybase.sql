-- A: Create a master key.
-- Only necessary if one does not already exist.
-- Required to encrypt the credential secret in the next step.

CREATE MASTER KEY;


-- B: Create a database scoped credential
-- IDENTITY: Provide any string, it is not used for authentication to Azure storage.
-- SECRET: Provide your Azure storage account key.


CREATE DATABASE SCOPED CREDENTIAL AzureStorageCredential
WITH
    IDENTITY = 'user',
    SECRET = '$storageAccountKey'
;


-- C: Create an external data source
-- TYPE: HADOOP - PolyBase uses Hadoop APIs to access data in Azure blob storage.
-- LOCATION: Provide Azure storage account name and blob container name.
-- CREDENTIAL: Provide the credential created in the previous step.

CREATE EXTERNAL DATA SOURCE AzureStorage
WITH (
    TYPE = HADOOP,
    LOCATION = 'wasbs://to-sqldw@$storageAccountName.blob.core.windows.net',
    CREDENTIAL = AzureStorageCredential
);

-- D: Create an external file format
-- FORMAT_TYPE: Type of file format in Azure storage (supported: DELIMITEDTEXT, RCFILE, ORC, PARQUET).
-- FORMAT_OPTIONS: Specify field terminator, string delimiter, date format etc. for delimited text files.
-- Specify DATA_COMPRESSION method if data is compressed.

CREATE EXTERNAL FILE FORMAT IntegrationTestFile
WITH (
    FORMAT_TYPE = DelimitedText,
    FORMAT_OPTIONS (FIELD_TERMINATOR = ',')
);


-- E: Create the external table
-- Specify column names and data types. This needs to match the data in the sample file.
-- LOCATION: Specify path to file or directory that contains the data (relative to the blob container).
-- To point to all files under the blob container, use LOCATION='.'

CREATE EXTERNAL TABLE dbo.IntegrationTestExt (
    Date NVARCHAR(400) NOT NULL
    , CustomerId NVARCHAR(400) NOT NULL
    , Name NVARCHAR(400) NOT NULL
    , NewName NVARCHAR(400) NOT NULL
    , SoundMatch SMALLINT NOT NULL
)
WITH (
    LOCATION='/',
    DATA_SOURCE=AzureStorage,
    FILE_FORMAT=IntegrationTestFile
);


-- Load data from Azure blob storage to SQL Data Warehouse

CREATE TABLE [dbo].[IntegrationTestInt]
WITH
(   
    CLUSTERED COLUMNSTORE INDEX
,   DISTRIBUTION = HASH([CustomerId])
)
AS
SELECT *
FROM   [dbo].[IntegrationTestExt]
;

-- Create Statistics on newly loaded data
-- Azure SQL Data Warehouse does not yet support auto create or auto update statistics

CREATE STATISTICS [CustomerId] ON [IntegrationTestInt] ([CustomerId]);
CREATE STATISTICS [Date] ON [IntegrationTestInt] ([Date]);
CREATE STATISTICS [Name] ON [IntegrationTestInt] ([Name]);
