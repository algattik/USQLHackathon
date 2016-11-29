

Requirements:
- Windows system with Internet connection without troublesome proxy
- Visual Studio
- Azure PowerShell
- Microsoft Windows PowerShell Extensions for Microsoft SQL Server 2012
- Azure subscription enabled for Azure Data Lake

Recommended but not required:
- Data Lake tools for Visual Studio

How to build and run:
- Change the config in the Configs directory.
  In particular the $namePrefix must be globally unique.
- Build the Visual Studio project in Release mode.
  (Downloaded dependencies are used to create ADLA assemblies later).
- In Windows PowerShell ISE, run the scripts in the Scripts directory.
  Watch for any errors.
- In Visual Studio, change the CIAMSimulator App.config file with your storage key
  and SQL database credentials.
- In Visual Studio, run the CIAMSimulator project. 

To try out the U-SQL files in Visual Studio:
- In Data Lake -> Options and Settings -> Local Run, find the location of your
  USQLRoot. Copy the directory Samples within it.


*** TODO ***

High:

- Write instructions for installing required tools on development VM.
- Create ADF job for transformation in Hive.

Medium:

- Provision additional infrastructure:
  * AAD tenant with sample users [Nicolas]
  * Service Bus (inbound Queue for Logic App)
  * Functions (to trigger Logic App)
- Split out the SASBroker from the CIAM Simulator into an API App.
  * The API App must be registered into AAD [Nicolas]
  * The API App must require valid AAD credentials from the caller,
  * The CIAM Simulator must be changed to call out the SASBroker API App.
- Write a Segmentation Web App Simulator that creates random segments from the
  data in SQL DW at regular intervals and writes the info in the service bus
  (it can be a basic console app).
- Write the Function that triggers the Logic App upon Queue messages.
- Write a Logic App that reads new segments from SQL DW and writes them out
  as JSON to a stubbed REST endpoint (representing the outgoing CIAM data)
- Scale up the Simulator to large datasets.
- Set up ADLS security (POSIX ACLs).
- Repeatability settings in ADF Polybase job.

Low:

- Set up sample Azure ML infrastructure
- Expand the currently extremely basic domain model
- Provision additional infrastructure: KeyVault
- The API App must store the Storage Key in the KeyVault rather than a config file.

*** NOTES ***

- The U-SQL script fails to decode json.gz in Visual Studio Data Lake Tools 2.2.0.0 because
  of a known bug.

