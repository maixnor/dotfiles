import subprocess
import os

def test_cli_no_secrets():
    print("Verifying the issue: Running maya-cli without secrets in environment...")
    # Clear environment variables that might be set
    env = os.environ.copy()
    env.pop("GEMINI_API_KEY", None)
    env.pop("DATABASE_URL", None)
    
    try:
        # We try to run brainstorm which triggers MayaOrchestrator -> MayaBlogEngine -> genai.Client
        # Even with --count 1 it should fail at initialization
        result = subprocess.run(
            ["maya-cli", "brainstorm", "--count", "1"],
            capture_output=True,
            text=True,
            env=env
        )
        if "ValueError: Missing key inputs argument!" in result.stderr:
            print("ISSUE VERIFIED: maya-cli failed as expected due to missing secrets.")
            print(f"Error output: {result.stderr.splitlines()[-1]}")
            return True
        else:
            print("Issue NOT verified. Unexpected output:")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            return False
    except FileNotFoundError:
        print("maya-cli not found in PATH. Make sure it is installed.")
        return False

if __name__ == "__main__":
    if test_cli_no_secrets():
        exit(0)
    else:
        exit(1)
