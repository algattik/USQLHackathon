-- Adapted from https://azure.microsoft.com/en-us/documentation/articles/hdinsight-using-json-in-hive/

DROP TABLE IF EXISTS CustomersRaw;
CREATE EXTERNAL TABLE CustomersRaw (textcol string) STORED AS TEXTFILE LOCATION "wasbs://from-ciam@$storageAccountName.blob.core.windows.net/";

DROP TABLE IF EXISTS CustomersOneLine;
CREATE EXTERNAL TABLE CustomersOneLine
(
  json_body string
)
STORED AS TEXTFILE LOCATION '/json/customers';

INSERT OVERWRITE TABLE CustomersOneLine
SELECT CONCAT_WS(' ',COLLECT_LIST(textcol)) AS singlelineJSON
      FROM (SELECT INPUT__FILE__NAME,BLOCK__OFFSET__INSIDE__FILE, textcol FROM CustomersRaw DISTRIBUTE BY INPUT__FILE__NAME SORT BY BLOCK__OFFSET__INSIDE__FILE) x
      GROUP BY INPUT__FILE__NAME;

add jar wasbs://hdinsight@$storageAccountName.blob.core.windows.net/json-serde.jar;

DROP TABLE json_table;
CREATE EXTERNAL TABLE json_table (
  export struct<
       `date`:string,
       customers:struct<
         customer:array<struct<
           CustomerID:string,
           Name:string
         >>
       >
  >
) ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION '/json/customers';

DROP TABLE reference_customers;
CREATE EXTERNAL TABLE reference_customers (
         CustomerID string,
         NameStyle string,
         Title string,
         FirstName string,
         MiddleName string,
         LastName string,
         Suffix string,
         CompanyName string,
         SalesPerson string,
         EmailAddress string,
         Phone string,
         PasswordHash string,
         PasswordSalt string,
         rowguid string,
         ModifiedDate string
)
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n' 
LOCATION "wasbs://from-db@$storageAccountName.blob.core.windows.net/";


DROP TABLE ciam_customers;
CREATE TABLE ciam_customers
AS select c.export.`date`, d.CustomerID, d.name from json_table c lateral view explode(export.customers.customer) collection as d;

INSERT OVERWRITE DIRECTORY "wasbs://to-sqldw@$storageAccountName.blob.core.windows.net/from-hive"
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' 
STORED AS TEXTFILE
SELECT cc.*,
	concat(rc.FirstName, ' ', rc.LastName)
	AS newName,
	-- TODO implement soundex match
	FALSE AS SoundMatch
FROM ciam_customers AS cc
LEFT OUTER JOIN reference_customers AS rc ON cc.CustomerID=rc.CustomerID

