import hashlib
import importlib.util
import io
import json
import pathlib
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('verifier', pathlib.Path(__file__).parents[1] / 'scripts/milou_verify_backup.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)

class BackupIntegrityTests(unittest.TestCase):
    def make_archive(self, directory, mutation=None):
        files = {'database.dump': b'PGDMP-test-only', 'database-inventory.txt': b'inventory', 'storage/storage-index.json': b'{"buckets": {}}'}
        manifest = {'project': 'lgdapxduxmhcixjwzfrq', 'file_count': len(files), 'files': {name: {'bytes': len(body), 'sha256': hashlib.sha256(body).hexdigest()} for name, body in files.items()}}
        files['manifest.json'] = json.dumps(manifest).encode()
        if mutation:
            mutation(files)
        filename = pathlib.Path(directory) / 'test.tar.gz'
        with tarfile.open(filename, 'w:gz') as archive:
            for name, body in files.items():
                entry = tarfile.TarInfo('./' + name)
                entry.size = len(body)
                archive.addfile(entry, io.BytesIO(body))
        return filename

    def test_intact_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            verifier.verify(self.make_archive(directory))

    def test_same_size_corruption_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            filename = self.make_archive(directory, lambda files: files.update({'database.dump': b'X' * len(files['database.dump'])}))
            with self.assertRaises(ValueError):
                verifier.verify(filename)

    def test_unlisted_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            filename = self.make_archive(directory, lambda files: files.update({'unexpected': b'x'}))
            with self.assertRaises(ValueError):
                verifier.verify(filename)

    def test_missing_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            filename = self.make_archive(directory, lambda files: files.pop('database.dump'))
            with self.assertRaises(ValueError):
                verifier.verify(filename)

    def test_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            filename = self.make_archive(directory, lambda files: files.update({'../outside': b'x'}))
            with self.assertRaises(ValueError):
                verifier.verify(filename)

if __name__ == '__main__':
    unittest.main()

