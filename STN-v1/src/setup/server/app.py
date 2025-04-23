
import requests
import json
import time
import os
from urllib.parse import unquote
import random
import string as strings

def create_file(filename):
    data = random.choices(strings.ascii_lowercase + strings.ascii_uppercase +
                          strings.digits, k=random.randint(50, 250))
    key = os.urandom(32)
    repeated_key = (key * (len(data) // len(key) + 1))[:len(data)]
    xored_result = ''.join(chr(ord(d) ^ k) for d, k in zip(data, repeated_key))
    with open(filename, "wb") as f:
        f.write(xored_result.encode())
    return True

def parse_config():
    # Parse configuration file to retrieve target URLs, file uploads, and download files.
    try:
        with open("config.json", "r") as f:
            config = json.load(f)
        return config["target-urls"], config["files"]["uploaded"], config["files"]["downloaded"], config["user-agent"]
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error reading config file: {e}")
        return [], [], [], ""

def check_website_online(target_urls):
    # Check if each target URL is online.
    for url in target_urls:
        try:
            response = requests.get(url)
            if response.status_code == 200:
                return url
            else:
                print(f"Error: {url} returned status code {response.status_code}")
        except requests.RequestException:
            print(f"Error: {url} is not online")
    return ""

def upload_file(url, file_path, user_agent):
    """Upload each file to the given URL."""
    headers = {"User-Agent": user_agent}
    create_file(file_path)
    try:
        with open(file_path, "rb") as file:
            files = {"file": file}
            data = {"filename": os.path.basename(file_path)}
            response = requests.post(f"{url}/upload", files=files, data=data, headers=headers)
            if response.status_code == 200:
                print(f"Uploaded {file_path} to {url}")
            else:
                print(f"Error: Failed to upload file {file_path} to {url} (status code: {response.status_code})")
    except FileNotFoundError:
        print(f"Error: File {file_path} not found.")
    except requests.RequestException as e:
        print(f"Error: Failed to upload file {file_path} to {url}: {e}")


def download_file(url, file_name, user_agent):
    # Download specified files from the target URL.
    headers = {"User-Agent": user_agent}
    params = {"file": unquote(file_name)}
    try:
        response = requests.get(f"{url}/download", params=params, headers=headers)
        print(response, response.status_code)
        if response.status_code == 200:
            print(f"Downloaded {file_name}")
        else:
            print(f"Error: Could not download {file_name} from {url} (status code: {response.status_code})")
    except requests.RequestException as e:
        print(f"Error: Download failed for {file_name} from {url}: {e}")

def main():
    # Main function to parse config, check URLs, upload files, and download files.
    target_urls, file_uploads, download_files, user_agent = parse_config()

    if not target_urls:
        print("No target URLs provided. Exiting.")
        return

    url = check_website_online(target_urls)
    if url:
        while True:
            if random.random() > 0.5:  # Fixed the random selection logic
                if file_uploads:
                    file = random.choice(file_uploads)
                    upload_file(url, file, user_agent)
                    os.remove(file)
            else:
                if download_files:
                    file = random.choice(download_files)
                    download_file(url, file, user_agent)
                    os.remove(file)
            time.sleep(1)  # Adding a delay to avoid overwhelming the server
    else:
        print("No machines online. Please check machine status and try again.")

if __name__ == "__main__":
    main()
