import os
import sys
import unittest
from unittest.mock import patch, mock_open
from utils import get_secret

class TestSecretLoading(unittest.TestCase):
    def test_get_secret_from_env(self):
        with patch.dict(os.environ, {"TEST_KEY": "env_value"}):
            self.assertEqual(get_secret("TEST_KEY"), "env_value")

    def test_get_secret_from_file(self):
        # Mocking the secret file content
        mock_content = "GEMINI_API_KEY=file_value\nDATABASE_URL=postgres://..."
        with patch("os.path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=mock_content)):
                # Ensure env var is NOT set
                with patch.dict(os.environ, {}, clear=True):
                    self.assertEqual(get_secret("GEMINI_API_KEY"), "file_value")

    def test_get_secret_missing_returns_none(self):
        with patch("os.path.exists", return_value=False):
            with patch.dict(os.environ, {}, clear=True):
                self.assertIsNone(get_secret("NON_EXISTENT_KEY"))

if __name__ == "__main__":
    unittest.main()

