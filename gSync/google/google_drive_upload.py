import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

def upload_file(json_path, file_path, file_name, folder_id=None):
    try:
        SCOPES = ['https://www.googleapis.com/auth/drive']
        creds = service_account.Credentials.from_service_account_file(json_path, scopes=SCOPES)
        service = build('drive', 'v3', credentials=creds)
        file_metadata = {
            'name': file_name,
            'parents': [folder_id] if folder_id else []  # Указываем родительскую папку, если задан ID
        }
        media = MediaFileUpload(file_path)
        file = service.files().create(body=file_metadata, media_body=media, fields='id').execute()
        print(f"File uploaded with ID: {file.get('id')}")
        return True
    except Exception as e:
        print(f"Error: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) not in (4, 5):  # 4 аргумента без folder_id, 5 с folder_id
        print("Usage: python google_drive_upload.py <path_to_service_account_json> <path_to_file> <file_name> [folder_id]")
        sys.exit(1)
    json_path, file_path, file_name = sys.argv[1], sys.argv[2], sys.argv[3]
    folder_id = sys.argv[4] if len(sys.argv) == 5 else None
    success = upload_file(json_path, file_path, file_name, folder_id)
    sys.exit(0 if success else 1)
