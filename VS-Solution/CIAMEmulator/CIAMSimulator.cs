using System;
using Microsoft.WindowsAzure.Storage.Blob;
using Newtonsoft.Json;
using System.IO.Compression;
using System.IO;
using System.Text;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Data.SqlClient;
using System.Configuration;

namespace USQLHackathon
{
    class CIAMSimulator
    {
        static void Main(string[] args)
        {

            string sasUri = SASTokenBroker.EmitSASToken();
            CloudBlobContainer container = new CloudBlobContainer(new Uri(sasUri));

            var advWorksConnectionString = ConfigurationManager.AppSettings["AdvWorksConnectionString"];
            var customers = new List<Customer>();
            using (SqlConnection conn = new SqlConnection(advWorksConnectionString))
            {
                conn.Open();
                using (SqlCommand command = new SqlCommand("SELECT CustomerID, FirstName, LastName FROM SalesLT.Customer", conn))
                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        customers.Add(
                        new Customer
                        {
                            customerid = reader.GetInt32(0).ToString(),
                            name = mangle(reader.GetString(1)) + " " + mangle(reader.GetString(2))
                        });
                    }
                }
            }

            // Retrieve reference to a blob
            const string blobName = "ciamdata.json.gz";
            CloudBlockBlob blockBlob = container.GetBlockBlobReference(blobName);

            // Create or overwrite the "myblob" blob with contents from a local file.
            ExportContainer export = new ExportContainer
            {
                export = new Export
                {
                    date = DateTime.Now.ToString("yyyy-MM-dd"),
                    customers = new Customers
                    {
                        customer = customers
                    }
                }
            };

            var output = JsonConvert.SerializeObject(export, Formatting.Indented);


            var inputString = output;
            byte[] compressed;

            using (var outStream = new MemoryStream())
            {
                using (var tinyStream = new GZipStream(outStream, CompressionMode.Compress))
                using (var mStream = new MemoryStream(Encoding.UTF8.GetBytes(inputString)))
                    mStream.CopyTo(tinyStream);

                compressed = outStream.ToArray();
            }

            using (var stream = new MemoryStream(compressed, writable: false))
            {
                blockBlob.UploadFromStream(stream);
            }


            //Require user input before closing the console window.
            int recordCount = customers.Count;
            Console.WriteLine("Successfully uploaded Blob '" + blobName + "' with " + recordCount + " records. Press RETURN to close window.");

            Console.ReadLine();
        }

        static Random rnd = new Random(1);

        private static string mangle(string v)
        {
            var v2 = new StringBuilder(v);
            if (rnd.Next(1, 5) == 1)
            {
                var pos = rnd.Next(0, v.Length - 1);
                v2[pos] = (char)('a' + rnd.Next(0, 25));
            }
            return v2.ToString();
        }
    }

    internal class ExportContainer
    {
        public Export export;
    }

    internal class Export
    {
        public string date;
        public Customers customers;
    }

    internal class Customers
    {
        public List<Customer> customer;
    }

    internal class Customer
    {
        public string customerid;
        public string name;
    }



}
