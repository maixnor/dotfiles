import os
from orchestrator import MayaOrchestrator
from unittest.mock import patch

def test_init():
    # Mocking the secret to avoid real API call
    with patch.dict(os.environ, {"GEMINI_API_KEY": "test_key"}):
        try:
            orc = MayaOrchestrator()
            print("Successfully initialized MayaOrchestrator")
            return True
        except Exception as e:
            print(f"Failed to initialize: {e}")
            return False

if __name__ == "__main__":
    if test_init():
        exit(0)
    else:
        exit(1)
