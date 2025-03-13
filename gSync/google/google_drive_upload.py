import os
import sys
import time
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Отключаем буферизацию для stdout
sys.stdout.reconfigure(line_buffering=True)

def check_file_exists(drive_service, file_name, folder_id):
    query = f"name='{file_name}' and '{folder_id}' in parents"
    results = drive_service.files().list(q=query, fields="files(id, name)").execute()
    return bool(results.get('files', []))

def upload_file(credentials_path, file_path, file_name, folder_id, chunk_size, start_offset, total_size, session_uri):
    # Загружаем учетные данные
    creds = Credentials.from_authorized_user_file(credentials_path, scopes=['https://www.googleapis.com/auth/drive'])
    
    # Проверяем и обновляем токен, если он истёк
    if creds.expired:
        creds.refresh(Request())
        print(f"Refreshed access token: {creds.token}", flush=True)
    
    drive_service = build('drive', 'v3', credentials=creds)

    try:
        # Проверка существования файла перед загрузкой
        if check_file_exists(drive_service, file_name, folder_id):
            print(f"File with name {file_name} already exists", flush=True)
            return True

        # Настройка чанковой загрузки
        CHUNK_SIZE = int(chunk_size)
        media = MediaFileUpload(file_path, chunksize=CHUNK_SIZE, resumable=True)
        request = drive_service.files().create(
            body={'name': file_name, 'parents': [folder_id]},
            media_body=media,
            fields='id'
        )
        current_session_uri = session_uri if session_uri != "None" else None
        if current_session_uri:
            request.uri = current_session_uri  # Возобновление с сохранённого URI

        uploaded_size = int(start_offset)
        last_progress_time = time.time()
        last_uploaded_size = uploaded_size

        print(f"Starting upload for {file_name}", flush=True)
        while True:
            try:
                status, response = request.next_chunk()
                if status:
                    uploaded_size = status.resumable_progress
                    current_time = time.time()
                    if current_time - last_progress_time >= 5:  # Обновляем прогресс каждые 5 секунд
                        progress = int((uploaded_size / int(total_size)) * 100)
                        time_diff = current_time - last_progress_time
                        bytes_uploaded = uploaded_size - last_uploaded_size
                        speed_mb_s = (bytes_uploaded / (1024 * 1024)) / time_diff if time_diff > 0 else 0
                        speed_mb_s = round(speed_mb_s)
                        current_session_uri = request.uri if hasattr(request, 'uri') else current_session_uri
                        print(f"PROGRESS:{progress}% SPEED:{speed_mb_s}", flush=True)
                        print(f"Sent progress {progress}% at {time.ctime(current_time)} with speed {speed_mb_s} Mb/s", flush=True)
                        print(f"SESSION_URI:{current_session_uri or 'None'}", flush=True)
                        last_progress_time = current_time
                        last_uploaded_size = uploaded_size
                    time.sleep(0.1)
                if response:
                    print(f"Upload completed with file ID: {response.get('id')}", flush=True)
                    return True  # Успешное завершение
            except Exception as e:
                print(f"Error: {str(e)}", flush=True)
                if "invalid_grant" in str(e) or "Token has been expired or revoked" in str(e):
                    creds.refresh(Request())
                    print(f"Refreshed access token: {creds.token}", flush=True)
                    drive_service = build('drive', 'v3', credentials=creds)
                    media = MediaFileUpload(file_path, chunksize=CHUNK_SIZE, resumable=True)
                    request = drive_service.files().create(
                        body={'name': file_name, 'parents': [folder_id]},
                        media_body=media,
                        fields='id'
                    )
                    if current_session_uri:
                        request.uri = current_session_uri
                    time.sleep(5)
                    continue
                elif "Broken pipe" in str(e) or "timeout" in str(e):
                    print(f"Retrying with session URI: {current_session_uri or 'None'}", flush=True)
                    media = MediaFileUpload(file_path, chunksize=CHUNK_SIZE, resumable=True)
                    request = drive_service.files().create(
                        body={'name': file_name, 'parents': [folder_id]},
                        media_body=media,
                        fields='id'
                    )
                    if current_session_uri:
                        request.uri = current_session_uri
                    time.sleep(10)
                    continue
                return False

    except Exception as e:
        print(f"Error: {str(e)}", flush=True)
        return False

if __name__ == "__main__":
    if len(sys.argv) != 9:
        print("Usage: python google_drive_upload.py <credentials_path> <file_path> <file_name> <folder_id> <chunk_size> <start_offset> <total_size> <session_uri>")
        sys.exit(1)

    credentials_path, file_path, file_name, folder_id, chunk_size, start_offset, total_size, session_uri = sys.argv[1:]
    success = upload_file(credentials_path, file_path, file_name, folder_id, chunk_size, start_offset, total_size, session_uri)
    sys.exit(0 if success else 1)
