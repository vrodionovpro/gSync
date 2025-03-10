import os
import sys
import google.auth
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
import time

def upload_file(service_account_path, file_path, file_name, folder_id):
    # Аутентификация с использованием сервисного аккаунта
    credentials, _ = google.auth.load_credentials_from_file(service_account_path)
    drive_service = build('drive', 'v3', credentials=credentials)

    try:
        # Проверка существования файла в указанной папке
        query = f"name='{file_name}' and '{folder_id}' in parents"
        results = drive_service.files().list(q=query, fields="files(id, name)").execute()
        if results.get('files', []):
            print(f"already exists")
            return False

        # Настройки для resumable upload с чанками по 256 MB
        CHUNK_SIZE = 256 * 1024 * 1024  # 256 MB
        file_size = os.path.getsize(file_path)
        media = MediaFileUpload(file_path,
                              chunksize=CHUNK_SIZE,
                              resumable=True)

        # Инициализация загрузки файла
        request = drive_service.files().create(
            body={'name': file_name, 'parents': [folder_id]},
            media_body=media,
            fields='id'
        )
        response = None
        uploaded_size = 0
        last_progress_time = time.time()

        while response is None:
            status, response = request.next_chunk()
            if status:
                uploaded_size = status.resumable_progress
                current_time = time.time()
                if current_time - last_progress_time >= 5:  # Обновление каждые 5 секунд
                    progress = int((uploaded_size / file_size) * 100)
                    print(f"PROGRESS:{progress}%", flush=True)  # Отправка прогресса
                    last_progress_time = current_time
            time.sleep(1)  # Пауза для стабильности

        print(f"Upload completed with file ID: {response.get('id')}")
        return True

    except Exception as e:
        print(f"Error: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python google_drive_upload.py <service_account_path> <file_path> <file_name> <folder_id>")
        sys.exit(1)

    service_account_path = sys.argv[1]
    file_path = sys.argv[2]
    file_name = sys.argv[3]
    folder_id = sys.argv[4]

    success = upload_file(service_account_path, file_path, file_name, folder_id)
    sys.exit(0 if success else 1)
