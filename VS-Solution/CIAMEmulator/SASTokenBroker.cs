using System;
using Microsoft.WindowsAzure.Storage.Blob;
using Microsoft.WindowsAzure.Storage;
using System.Configuration;

namespace USQLHackathon
{
    public class SASTokenBroker
    {

        public static string EmitSASToken()
        {
            //Parse the connection string and return a reference to the storage account.
            var storageConnectionString = ConfigurationManager.AppSettings["StorageConnectionString"];
            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(storageConnectionString);

            //Create the blob client object.
            CloudBlobClient blobClient = storageAccount.CreateCloudBlobClient();

            //Get a reference to a container to use for the sample code.
            CloudBlobContainer container = blobClient.GetContainerReference("from-ciam");

            //Generate a SAS URI for the container, without a stored access policy.
            Console.WriteLine("Container SAS URI: " + GetContainerSasUri(container));
            Console.WriteLine();


            //Clear any existing access policies on container.
            BlobContainerPermissions perms = container.GetPermissions();
            perms.SharedAccessPolicies.Clear();
            container.SetPermissions(perms);

            //Create a new access policy on the container, which may be optionally used to provide constraints for
            //shared access signatures on the container and the blob.
            string sharedAccessPolicyName = "ciam-policy";
            CreateSharedAccessPolicy(blobClient, container, sharedAccessPolicyName);

            //Generate a SAS URI for the container, using a stored access policy to set constraints on the SAS.
            var sasUri = GetContainerSasUriWithPolicy(container, sharedAccessPolicyName);
            Console.WriteLine("Container SAS URI using stored access policy: " + sasUri);
            Console.WriteLine();

            return sasUri;
        }

        static string GetContainerSasUri(CloudBlobContainer container)
        {
            //Set the expiry time and permissions for the container.
            //In this case no start time is specified, so the shared access signature becomes valid immediately.
            SharedAccessBlobPolicy sasConstraints = new SharedAccessBlobPolicy();
            sasConstraints.SharedAccessExpiryTime = DateTime.UtcNow.AddHours(4);
            sasConstraints.Permissions = SharedAccessBlobPermissions.Write | SharedAccessBlobPermissions.List;

            //Generate the shared access signature on the container, setting the constraints directly on the signature.
            string sasContainerToken = container.GetSharedAccessSignature(sasConstraints);

            //Return the URI string for the container, including the SAS token.
            return container.Uri + sasContainerToken;
        }

        public static void CreateSharedAccessPolicy(CloudBlobClient blobClient, CloudBlobContainer container, string policyName)
        {
            //Create a new stored access policy and define its constraints.
            SharedAccessBlobPolicy sharedPolicy = new SharedAccessBlobPolicy()
            {
                SharedAccessExpiryTime = DateTime.UtcNow.AddHours(10),
                Permissions = SharedAccessBlobPermissions.Read | SharedAccessBlobPermissions.Write | SharedAccessBlobPermissions.List
            };

            //Get the container's existing permissions.
            BlobContainerPermissions permissions = new BlobContainerPermissions();

            //Add the new policy to the container's permissions.
            permissions.SharedAccessPolicies.Clear();
            permissions.SharedAccessPolicies.Add(policyName, sharedPolicy);
            container.SetPermissions(permissions);
        }

        public static string GetContainerSasUriWithPolicy(CloudBlobContainer container, string policyName)
        {
            //Generate the shared access signature on the container. In this case, all of the constraints for the 
            //shared access signature are specified on the stored access policy.
            string sasContainerToken = container.GetSharedAccessSignature(null, policyName);

            //Return the URI string for the container, including the SAS token.
            return container.Uri + sasContainerToken;
        }



    }
}
