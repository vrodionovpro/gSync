import os
import sys
import google.auth
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
import time

# Отключаем буферизацию для stdout
sys.stdout.reconfigure(line_buffering=True)

def get_storage_quota(service):
    try:
        about = service.about().get(fields="storageQuota").execute()
        return int(about['storageQuota']['limit']), int(about['storageQuota']['usage'])
    except Exception as e:
        print(f"Error checking quota: {str(e)}", flush=True)
        return None, None

def upload_file(service_account_path, file_path, file_name, folder_id, chunk_size, start_offset, total_size, session_uri):
    credentials, _ = google.auth.load_credentials_from_file(service_account_path)
    drive_service = build('drive', 'v3', credentials=credentials)

    try:
        # Проверка квоты
        total, used = get_storage_quota(drive_service)
        if total is None or used is None:
            return False
        file_size = os.path.getsize(file_path)
        if total - used < file_size:
            print(f"Error: Insufficient space. Free: {total - used} bytes, Required: {file_size} bytes", flush=True)
            return False

        # Проверка существования файла
        query = f"name='{file_name}' and '{folder_id}' in parents"
        results = drive_service.files().list(q=query, fields="files(id, name)").execute()
        if results.get('files', []):
            print(f"File with name {file_name} already exists (ID: {results['files'][0]['id']})", flush=True)
            return False

        # Настройка чанковой загрузки
        CHUNK_SIZE = int(chunk_size)
        media = MediaFileUpload(file_path, chunksize=CHUNK_SIZE, resumable=True)
        request = drive_service.files().create(
            body={'name': file_name, 'parents': [folder_id]},
            media_body=media,
            fields='id'
        )
        if session_uri != "None":
            request.uri = session_uri  # Возобновление с сохранённого URI

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
                    if current_time - last_progress_time >= 5:
                        progress = int((uploaded_size / file_size) * 100)
                        time_diff = current_time - last_progress_time
                        bytes_uploaded = uploaded_size - last_uploaded_size
                        speed_mb_s = (bytes_uploaded / (1024 * 1024)) / time_diff if time_diff > 0 else 0
                        speed_mb_s = round(speed_mb_s)
                        print(f"PROGRESS:{progress}% SPEED:{speed_mb_s}", flush=True)
                        print(f"Sent progress {progress}% at {time.ctime(current_time)} with speed {speed_mb_s} Mb/s", flush=True)
                        print(f"SESSION_URI:{status.resumable_uri}", flush=True)
                        last_progress_time = current_time
                        last_uploaded_size = uploaded_size
                    time.sleep(0.1)
                if response:
                    print(f"Upload completed with file ID: {response.get('id')}", flush=True)
                    return True
            except Exception as e:
                print(f"Error: {str(e)}", flush=True)
                if "Broken pipe" in str(e) or "timeout" in str(e):
                    print(f"Retrying with session URI: {status.resumable_uri if status else session_uri}", flush=True)
                    media = MediaFileUpload(file_path, chunksize=CHUNK_SIZE, resumable=True)
                    request = drive_service.files().create(
                        body={'name': file_name, 'parents': [folder_id]},
                        media_body=media,
                        fields='id'
                    )
                    request.uri = status.resumable_uri if status else session_uri
                    time.sleep(10)
                    continue
                return False

    except Exception as e:
        print(f"Error: {str(e)}", flush=True)
        return False

if __name__ == "__main__":
    if len(sys.argv) != 9:
        print("Usage: python google_drive_upload.py <service_account_path> <file_path> <file_name> <folder_id> <chunk_size> <start_offset> <total_size> <session_uri>")
        sys.exit(1)

    service_account_path, file_path, file_name, folder_id, chunk_size, start_offset, total_size, session_uri = sys.argv[1:]
    success = upload_file(service_account_path, file_path, file_name, folder_id, chunk_size, start_offset, total_size, session_uri)
    sys.exit(0 if success else 1)
