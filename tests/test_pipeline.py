"""Workflow regression tests with stub tools; no biological validation."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'src' / 'GERMINATE.sh'
STUB = '''#!/usr/bin/env python3
import os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
def output(flag):
    return Path(args[args.index(flag) + 1])
if name == 'clustalo':
    if os.environ.get('FAIL_ALIGNMENT'):
        sys.exit(7)
    output('-o').write_text('>seed\\nMPEPTIDE\\n')
elif name == 'hmmbuild':
    Path(args[0]).write_text('mock model')
elif name == 'hmmsearch':
    rows = '# header\\n# Program: hmmsearch\\n'
    if not os.environ.get('NO_HITS'):
        rows += 'protein_A - gene - 1e-120 400\\nprotein_B - gene - 1e-20 50\\n'
    output('--tblout').write_text(rows)
elif name == 'seqkit':
    assert output('-f').read_text() == 'protein_A\\n'
    print('>protein_A\\nMPEPTIDE')
elif name == 'cd-hit':
    output('-o').write_text(output('-i').read_text())
    Path(str(output('-o')) + '.clstr').write_text('mock cluster')
'''

class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.seeds = self.root / 'seed directory'
        self.seeds.mkdir()
        (self.seeds / 'gene one_seeds.faa').write_text('>seed\nMPEPTIDE\n')
        db = self.root / 'database.faa'
        db.write_text('>protein_A\nMPEPTIDE\n')
        self.out = self.root / 'output directory'
        bins = self.root / 'bin'
        bins.mkdir()
        for name in ['clustalo', 'hmmbuild', 'hmmsearch', 'seqkit', 'cd-hit']:
            tool = bins / name
            tool.write_text(STUB)
            tool.chmod(0o755)
        self.env = dict(os.environ, PATH=str(bins) + os.pathsep + os.environ['PATH'],
                        SEED_DIR=str(self.seeds), DB=str(db), OUTDIR=str(self.out))
    def run_pipeline(self, *args, **env):
        return subprocess.run(['bash', str(SCRIPT), *args], env=dict(self.env, **env),
                              capture_output=True, text=True)
    def test_success_and_comment_filter(self):
        result = self.run_pipeline()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.out / 'gene one_hits.list').read_text(), 'protein_A\n')
        self.assertIn('protein_A', (self.out / 'gene one_nr.faa').read_text())
        self.assertNotEqual(self.run_pipeline().returncode, 0)
    def test_zero_hits(self):
        result = self.run_pipeline(NO_HITS='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.out / 'gene one_nr.faa').read_text(), '')
    def test_failure_stops_pipeline(self):
        result = self.run_pipeline(FAIL_ALIGNMENT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.out / 'gene one.hmm').exists())
        self.assertNotIn('finished successfully', result.stdout)
    def test_empty_seed_directory(self):
        next(self.seeds.iterdir()).unlink()
        self.assertNotEqual(self.run_pipeline().returncode, 0)
    def test_invalid_threads(self):
        self.assertNotEqual(self.run_pipeline('0').returncode, 0)
    def test_missing_database(self):
        self.assertNotEqual(self.run_pipeline(DB=str(self.root / 'missing')).returncode, 0)
    def test_invalid_cutoff(self):
        self.assertNotEqual(self.run_pipeline(EVALUE='invalid').returncode, 0)

if __name__ == '__main__':
    unittest.main()
