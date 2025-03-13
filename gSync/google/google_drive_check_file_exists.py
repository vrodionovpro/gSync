import sys
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

def check_file_exists(credentials_path, file_name, folder_id):
    try:
        print(f"Checking file {file_name} in folder {folder_id}")
        creds = Credentials.from_authorized_user_file(credentials_path, scopes=['https://www.googleapis.com/auth/drive'])
        if creds.expired:
            creds.refresh(Request())
        service = build('drive', 'v3', credentials=creds)
        query = f"'{folder_id}' in parents and name = '{file_name}'"
        results = service.files().list(q=query, fields="files(id, name)").execute()
        files = results.get('files', [])
        if files:
            print(f"File with name {file_name} already exists (ID: {files[0]['id']})")
            return True
        print(f"No file with name {file_name} found in folder {folder_id}")
        return False
    except Exception as e:
        print(f"Error: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python google_drive_check_file_exists.py <path_to_credentials_json> <file_name> <folder_id>")
        sys.exit(1)
    credentials_path, file_name, folder_id = sys.argv[1], sys.argv[2], sys.argv[3]
    success = check_file_exists(credentials_path, file_name, folder_id)
    sys.exit(0 if success else 1)
