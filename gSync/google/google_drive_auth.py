import sys
from google.oauth2 import service_account
from google.auth.transport.requests import Request

def get_drive_credentials(json_path):
    try:
        SCOPES = ['https://www.googleapis.com/auth/drive']
        creds = service_account.Credentials.from_service_account_file(json_path, scopes=SCOPES)
        creds.refresh(Request())
        print("Authentication successful")
        print(f"Access token: {creds.token}")
        return True
    except Exception as e:
        print(f"Error: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python google_drive_auth.py <path_to_service_account_json>")
        sys.exit(1)
    json_path = sys.argv[1]
    success = get_drive_credentials(json_path)
    sys.exit(0 if success else 1)  # Выходим с кодом 0 при успехе, 1 при ошибке
