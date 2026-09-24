import io                        # lets Python treat downloaded bytes like a file
import os                        # lets Python read environment variables
import zipfile                   # lets Python open and unzip zip files
from pathlib import Path         # lets Python build folder paths safely

import requests                  # lets Python download from the internet
from dotenv import load_dotenv                     # lets Python read your .env file
from azure.storage.blob import BlobServiceClient    # the Azure SDK tool that uploads files

# The zip Cricsheet publishes with every IPL match (one CSV per match)
URL = "https://cricsheet.org/downloads/ipl_csv2.zip"

# Where the unzipped files will go: raw_data/cricsheet inside the repo.
# Built relative to this script so it works on any machine.
RAW_DIR = Path(__file__).parent.parent / "raw_data" / "cricsheet"

# --- Azure setup ---
load_dotenv()  # reads .env and makes AZURE_STORAGE_CONNECTION_STRING available

CONNECTION_STRING = os.environ["AZURE_STORAGE_CONNECTION_STRING"]  # pulls the secret out of .env
CONTAINER_NAME = "cricsheet-raw"                                   # your container's name

blob_service_client = BlobServiceClient.from_connection_string(CONNECTION_STRING)  # opens a connection to your storage account
container_client = blob_service_client.get_container_client(CONTAINER_NAME)       # points specifically at your container


def fetch():
    # Create the folder if it's missing; don't complain if it already exists
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Downloading {URL} ...")

    # Download the zip; give up after 60 seconds if the site doesn't respond
    response = requests.get(URL, timeout=60)

    # Stop with an error if the download failed (e.g. 404)
    response.raise_for_status()

    # Open the downloaded bytes as a zip (in memory, no temp file)
    with zipfile.ZipFile(io.BytesIO(response.content)) as zf:
        # Names of files already in the folder (so we can skip them)
        existing = {f.name for f in RAW_DIR.iterdir()}

        # Files in the zip that we don't have yet
        new_files = [name for name in zf.namelist() if name not in existing]

        # Extract only those
        zf.extractall(RAW_DIR, members=new_files)

    print(f"Added {len(new_files)} new files")

    # Count the CSVs now in the folder, as a sanity check
    files = list(RAW_DIR.glob("*.csv"))
    print(f"Total: {len(files)} CSV files in {RAW_DIR}")


def upload_to_azure():
    # Get a list of blob names (files) that already exist in the Azure container
    existing_blobs = set(blob.name for blob in container_client.list_blobs())  # set() makes "already there?" checks fast

    # Loop through every CSV file that's sitting locally in raw_data/cricsheet
    for local_file in RAW_DIR.glob("*.csv"):
        blob_name = local_file.name  # the filename Azure will use, e.g. "1082591.csv"

        if blob_name in existing_blobs:
            continue  # skip it, it's already uploaded, keeps this idempotent

        print(f"Uploading {blob_name} to Azure...")
        with open(local_file, "rb") as data:              # "rb" = read the file as raw bytes
            container_client.upload_blob(name=blob_name, data=data)  # sends the file to Azure


# Only run fetch() when this file is run directly, not when it's imported
if __name__ == "__main__":
    fetch()
    upload_to_azure()  # after downloading locally, push anything new up to Azure