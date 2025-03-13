import sys
import json
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# Загружаем токены из credentials.json
creds = Credentials.from_authorized_user_file(sys.argv[1], scopes=['https://www.googleapis.com/auth/drive'])
if creds.expired:
    creds.refresh(Request())

service = build('drive', 'v3', credentials=creds)

# Проверяем квоту
about = service.about().get(fields="storageQuota").execute()
quota = {"total": int(about['storageQuota']['limit']), "used": int(about['storageQuota']['usage'])}
print(json.dumps(quota), flush=True)
sys.exit(0)
