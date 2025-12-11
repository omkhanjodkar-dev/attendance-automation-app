import pandas as pd
import os

# Path to the Excel file
file_path = r"..\assets\Proj_data.xlsx"

try:
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        # Try absolute path based on what we know
        file_path = r"c:\Proj_flut\new_app\assets\Proj_data.xlsx"

    print(f"Reading file: {file_path}")
    df = pd.read_excel(file_path)
    
    print("\nColumns Found:")
    print(df.columns.tolist())
    
    print("\nFirst 3 rows:")
    print(df.head(3))

except ImportError:
    print("Error: pandas or openpyxl not installed. Please run: pip install pandas openpyxl")
except Exception as e:
    print(f"An error occurred: {e}")
