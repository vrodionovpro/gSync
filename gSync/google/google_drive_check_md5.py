import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build

def check_file_exists_by_md5(json_path, md5_hash, folder_id):
    try:
        print(f"Checking MD5 {md5_hash} in folder {folder_id}")
        SCOPES = ['https://www.googleapis.com/auth/drive']
        creds = service_account.Credentials.from_service_account_file(json_path, scopes=SCOPES)
        service = build('drive', 'v3', credentials=creds)
        query = f"'{folder_id}' in parents"
        results = service.files().list(q=query, fields="files(id, name, md5Checksum)").execute()
        files = results.get('files', [])
        for file in files:
            print(f"Checking file: {file['name']} (MD5: {file.get('md5Checksum')})")
            if file.get('md5Checksum') == md5_hash:
                print(f"File with MD5 {md5_hash} already exists (ID: {file['id']}, Name: {file['name']})")
                return True
        print(f"No file with MD5 {md5_hash} found in folder {folder_id}")
        return False
    except Exception as e:
        print(f"Error: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python google_drive_check_md5.py <path_to_service_account_json> <md5_hash> <folder_id>")
        sys.exit(1)
    json_path, md5_hash, folder_id = sys.argv[1], sys.argv[2], sys.argv[3]
    success = check_file_exists_by_md5(json_path, md5_hash, folder_id)
    sys.exit(0 if success else 1)
