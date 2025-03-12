import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
import json

creds = service_account.Credentials.from_service_account_file(sys.argv[1], scopes=['https://www.googleapis.com/auth/drive'])
service = build('drive', 'v3', credentials=creds)
about = service.about().get(fields="storageQuota").execute()
quota = {"total": int(about['storageQuota']['limit']), "used": int(about['storageQuota']['usage'])}
print(json.dumps(quota), flush=True)
sys.exit(0)
