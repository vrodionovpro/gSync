import sys
import json
from google.oauth2 import service_account
from googleapiclient.discovery import build

def list_folders(json_path):
    try:
        SCOPES = ['https://www.googleapis.com/auth/drive']
        creds = service_account.Credentials.from_service_account_file(json_path, scopes=SCOPES)
        service = build('drive', 'v3', credentials=creds)
        
        # Запрашиваем все папки, включая вложенные
        page_token = None
        folders = []
        while True:
            results = service.files().list(
                q="mimeType='application/vnd.google-apps.folder'",
                spaces='drive',
                fields="nextPageToken, files(id, name, parents)",
                pageToken=page_token
            ).execute()
            folders.extend(results.get('files', []))
            page_token = results.get('nextPageToken', None)
            if page_token is None:
                break

        if not folders:
            print("No folders found in the Drive space accessible by this Service Account.")
            print(json.dumps([]))  # Возвращаем пустой список в формате JSON
            return True

        # Формируем иерархию папок
        folder_dict = {folder['id']: {'id': folder['id'], 'name': folder['name'], 'children': []} for folder in folders}
        root_folders = []

        for folder in folders:
            folder_id = folder['id']
            parents = folder.get('parents', [])
            if not parents:
                root_folders.append(folder_dict[folder_id])
            else:
                for parent_id in parents:
                    if parent_id in folder_dict:
                        folder_dict[parent_id]['children'].append(folder_dict[folder_id])
                    else:
                        # Если родитель не найден среди папок, добавляем как корневую
                        root_folders.append(folder_dict[folder_id])

        # Выводим результат в формате JSON
        print(json.dumps(root_folders, indent=2))
        return True
    except Exception as e:
        print(f"Error: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python google_drive_list_folders.py <path_to_service_account_json>")
        sys.exit(1)
    json_path = sys.argv[1]
    success = list_folders(json_path)
    sys.exit(0 if success else 1)
