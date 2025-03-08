import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build

def list_files(json_path):
    try:
        SCOPES = ['https://www.googleapis.com/auth/drive']
        creds = service_account.Credentials.from_service_account_file(json_path, scopes=SCOPES)
        service = build('drive', 'v3', credentials=creds)
        results = service.files().list(pageSize=10, fields="files(id, name)").execute()
        files = results.get('files', [])
        for file in files:
            print(f"File: {file['name']} (ID: {file['id']})")
        return True
    except Exception as e:
        print(f"Error: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python google_drive_list_files.py <path_to_service_account_json>")
        sys.exit(1)
    json_path = sys.argv[1]
    success = list_files(json_path)
    sys.exit(0 if success else 1)