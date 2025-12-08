import pandas as pd
import os

def generate_sql():
    # File Path
    excel_path = r"c:\Proj_flut\new_app\assets\Proj_data.xlsx"
    output_path = r"c:\Proj_flut\new_app\backend\students.sql"
    
    if not os.path.exists(excel_path):
        print(f"Error: Excel file not found at {excel_path}")
        return

    print("Reading Excel file...")
    try:
        df = pd.read_excel(excel_path)
    except Exception as e:
        print(f"Failed to read Excel: {e}")
        return

    # Clean column names
    df.columns = [c.strip() for c in df.columns]
    
    count = 0
    with open(output_path, "w") as f:
        f.write("-- Bulk Import Students\n")
        
        for index, row in df.iterrows():
            email = str(row['STUDENT EMAIL ID']).strip()
            prn = str(row['PRN']).strip()
            
            if not email or not prn or email == 'nan':
                continue

            # Escape single quotes in names just in case
            email = email.replace("'", "''")
            prn = prn.replace("'", "''")

            # Generate SQL line
            sql = f"INSERT INTO students (username, password) VALUES ('{email}', '{prn}') ON CONFLICT (username) DO NOTHING;\n"
            f.write(sql)
            count += 1
            
    print(f"\nSUCCESS! Generated SQL for {count} students.")
    print(f"File saved to: {output_path}")

if __name__ == "__main__":
    generate_sql()
