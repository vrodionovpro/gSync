#
//  calculate_total_size.py
//  gSync
//
//  Created by 0000 on 13.03.2025.
//
import sys
import os

def calculate_total_size(file_paths):
    total_size = 0
    for path in file_paths:
        total_size += os.path.getsize(path)
    return total_size

if __name__ == "__main__":
    paths = sys.argv[1:]  # Первый аргумент — serviceAccountPath, остальные — пути
    print(calculate_total_size(paths[1:]))  # Пропускаем serviceAccountPath
