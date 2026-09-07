import io                        # lets Python treat downloaded bytes like a file
import zipfile                   # lets Python open and unzip zip files
from pathlib import Path         # lets Python build folder paths safely

import requests                  # lets Python download from the internet

# The zip Cricsheet publishes with every IPL match (one CSV per match)
URL = "https://cricsheet.org/downloads/ipl_csv2.zip"

# Where the unzipped files will go: raw_data/cricsheet inside the repo.
# Built relative to this script so it works on any machine.
RAW_DIR = Path(__file__).parent.parent / "raw_data" / "cricsheet"


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


# Only run fetch() when this file is run directly, not when it's imported
if __name__ == "__main__":
    fetch()