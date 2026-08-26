import unittest
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from utils import extract_relative_path, human_size, build_tree_structure

class TestUtils(unittest.TestCase):
    def test_extract_relative_path(self):
        self.assertEqual(extract_relative_path("http://example.onion/a/b/c.txt"), "/a/b/c.txt")
        self.assertEqual(extract_relative_path("http://test.onion/"), "/")
        self.assertEqual(extract_relative_path("not_a_url"), "not_a_url")

    def test_human_size(self):
        self.assertEqual(human_size(500), "500 B")
        self.assertEqual(human_size(1024), "1.0 KB")
        self.assertEqual(human_size(1048576), "1.0 MB")
        self.assertEqual(human_size(1536), "1.5 KB")
        self.assertEqual(human_size(0), "")
        self.assertEqual(human_size(None), "")

    def test_build_tree_structure(self):
        tasks = [
            {"url": "http://test.onion/a/b.txt", "is_dir": 0},
            {"url": "http://test.onion/a/c/", "is_dir": 1},
        ]
        tree = build_tree_structure(tasks)
        self.assertEqual(tree["name"], "root")
        self.assertTrue("a" in tree["children"])
        self.assertTrue("b.txt" in tree["children"]["a"]["children"])
        self.assertTrue("c" in tree["children"]["a"]["children"])

if __name__ == '__main__':
    unittest.main()
