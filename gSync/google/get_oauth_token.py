import sys
import json
import os
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ['https://www.googleapis.com/auth/drive']

def main(config_path, output_path):
    # Читаем конфигурацию из файла
    with open(config_path, 'r') as f:
        client_config = json.load(f)
    
    flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
    creds = flow.run_local_server(port=0)
    
    # Формируем данные для credentials.json
    credentials_data = {
        "refresh_token": creds.refresh_token,
        "token_uri": creds.token_uri,
        "client_id": creds.client_id,
        "client_secret": creds.client_secret,
        "scopes": SCOPES
    }
    
    # Сохраняем в указанный путь
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    with open(output_path, 'w') as f:
        json.dump(credentials_data, f, indent=2)
    
    print(f"New credentials saved to {output_path}")
    print(f"Access token: {creds.token}")
    print(f"Refresh token: {creds.refresh_token}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python get_oauth_token.py <config_path> <output_path>")
        sys.exit(1)
    
    config_path = sys.argv[1]
    output_path = sys.argv[2]
    main(config_path, output_path)
    sys.exit(0)
