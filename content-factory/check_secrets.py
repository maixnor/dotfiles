import os

def check_secret_file():
    path = "/run/secrets/content-factory.env"
    print(f"Checking {path}...")
    if not os.path.exists(path):
        print("File does not exist.")
        return
    
    print("File exists.")
    try:
        with open(path, "r") as f:
            lines = f.readlines()
            print(f"Read {len(lines)} lines.")
            for i, line in enumerate(lines):
                line = line.strip()
                if "=" in line:
                    k, v = line.split("=", 1)
                    print(f"Line {i}: Key='{k.strip()}', Value present: {bool(v.strip())}")
                else:
                    print(f"Line {i}: No '=' found, starts with: '{line[:10]}...'")
    except Exception as e:
        print(f"Could not read file: {e}")

if __name__ == "__main__":
    check_secret_file()
