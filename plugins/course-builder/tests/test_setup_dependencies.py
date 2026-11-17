"""Chạy bằng python3 -m unittest discover -s plugins/course-builder/tests -v.

Giả lập hệ điều hành và trình quản lý gói; không tải/cài phần mềm trên máy test.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'setup-dependencies.sh'
TOOLS = ('bash', 'curl', 'jq', 'openssl', 'node', 'npx')


class SetupDependenciesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='course builder setup ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'commands.jsonl'
        self.env = dict(os.environ, PATH=str(self.bin), HOME=str(self.root),
                        SETUP_TEST_BIN=str(self.bin), SETUP_TEST_LOG=str(self.log))
        self.stub('uname', 'printf "Linux\\n"')
        self.stub('id', 'printf "0\\n"')
        for tool in TOOLS:
            self.stub(tool, 'exit 0')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)

    def manager(self, name):
        path = self.bin / name
        path.write_text(f'#!{sys.executable}\n' + '''
import json, os, pathlib, sys
with open(os.environ['SETUP_TEST_LOG'], 'a') as out:
    out.write(json.dumps([pathlib.Path(sys.argv[0]).name] + sys.argv[1:]) + '\\n')
if os.environ.get('SETUP_TEST_FAIL'):
    sys.exit(42)
if sys.argv[1:] == ['--prefix']:
    print(os.environ['HOME'] + '/brew')
    sys.exit(0)
if 'update' in sys.argv:
    sys.exit(0)
for package in sys.argv[1:]:
    names = {'nodejs': ['node'], 'npm': ['npx'], 'openssl@3': ['openssl']}.get(package, [package])
    for name in names:
        if name not in ('bash', 'curl', 'jq', 'openssl', 'node', 'npx'):
            continue
        path = pathlib.Path(os.environ['SETUP_TEST_BIN']) / name
        path.write_text('#!/bin/sh\\nexit 0\\n')
        path.chmod(0o755)
''')
        path.chmod(0o755)

    def run_script(self, *args):
        return subprocess.run(['/bin/sh', str(SCRIPT), *args], env=self.env,
                              text=True, capture_output=True, timeout=10)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_already_ready_does_not_install(self):
        self.manager('apt-get')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ĐÃ SẴN SÀNG', result.stdout)
        self.assertEqual(self.calls(), [])

    def test_check_is_read_only_when_missing(self):
        (self.bin / 'jq').unlink()
        self.manager('apt-get')
        result = self.run_script('--check')
        self.assertEqual(result.returncode, 1)
        self.assertIn('THIẾU  jq', result.stdout)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.bin / 'jq').exists())

    def test_missing_bash_can_be_bootstrapped_with_sh(self):
        (self.bin / 'bash').unlink()
        self.manager('apt-get')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [['apt-get', 'update'], ['apt-get', 'install', '-y', 'bash']])

    def test_installs_only_missing_packages_and_is_repeatable(self):
        for tool in ('jq', 'node', 'npx'):
            (self.bin / tool).unlink()
        self.manager('apt-get')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = [['apt-get', 'update'], ['apt-get', 'install', '-y', 'jq', 'nodejs', 'npm']]
        self.assertEqual(self.calls(), expected)
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), expected)

    def test_npx_checked_even_when_node_exists(self):
        (self.bin / 'npx').unlink()
        self.manager('apt-get')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1], ['apt-get', 'install', '-y', 'npm'])

    def test_other_linux_managers(self):
        cases = {
            'dnf': ['install', '-y', 'jq'],
            'yum': ['install', '-y', 'jq'],
            'apk': ['add', '--no-cache', 'jq'],
            'pacman': ['-S', '--needed', '--noconfirm', 'jq'],
            'zypper': ['--non-interactive', 'install', 'jq'],
        }
        for manager, args in cases.items():
            with self.subTest(manager=manager):
                (self.bin / 'jq').unlink()
                self.manager(manager)
                result = self.run_script()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls()[-1], [manager] + args)
                (self.bin / manager).unlink()

    def test_macos_uses_homebrew_and_sets_profile_once(self):
        self.stub('uname', 'printf "Darwin\\n"')
        self.env['SHELL'] = '/bin/zsh'
        os.symlink(shutil.which('grep'), self.bin / 'grep')
        self.manager('brew')
        for tool in ('jq', 'openssl'):
            (self.bin / tool).unlink()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [['brew', 'install', 'jq', 'openssl@3'], ['brew', '--prefix']])
        profile = self.root / '.zprofile'
        self.assertEqual(profile.read_text().count('# Course Builder tools'), 1)
        (self.bin / 'jq').unlink()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(profile.read_text().count('# Course Builder tools'), 1)

    def test_macos_check_does_not_modify_profile_or_install(self):
        self.stub('uname', 'printf "Darwin\\n"')
        self.manager('brew')
        (self.bin / 'jq').unlink()
        result = self.run_script('--check')
        self.assertEqual(result.returncode, 1)
        self.assertFalse((self.root / '.zprofile').exists())
        self.assertEqual(self.calls(), [])

    def test_non_root_uses_sudo(self):
        self.stub('id', 'printf "1000\\n"')
        self.stub('sudo', 'exec "$@"')
        (self.bin / 'curl').unlink()
        self.manager('apt-get')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1], ['apt-get', 'install', '-y', 'curl'])

    def test_missing_admin_permission_is_reported(self):
        self.stub('id', 'printf "1000\\n"')
        (self.bin / 'curl').unlink()
        self.manager('apt-get')
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('quyền quản trị', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_install_failure_does_not_claim_success(self):
        (self.bin / 'jq').unlink()
        self.manager('apt-get')
        self.env['SETUP_TEST_FAIL'] = '1'
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('ĐÃ SẴN SÀNG', result.stdout)
        self.assertFalse((self.bin / 'jq').exists())

    def test_post_install_verification_detects_missing_tools(self):
        (self.bin / 'jq').unlink()
        self.stub('apt-get', 'exit 0')
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Vẫn thiếu công cụ', result.stderr)
        self.assertNotIn('ĐÃ SẴN SÀNG', result.stdout)

    def test_unsupported_platform_reports_next_step(self):
        self.stub('uname', 'printf "FreeBSD\\n"')
        (self.bin / 'jq').unlink()
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('FreeBSD', result.stderr)

    def test_linux_without_supported_package_manager(self):
        (self.bin / 'jq').unlink()
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('trình quản lý gói', result.stderr)

    def test_git_bash_dispatches_to_powershell_with_space_in_path(self):
        self.stub('uname', 'printf "MINGW64_NT-10.0\\n"')
        self.stub('cygpath', 'printf "%s\\n" "$2"')
        # Dùng bản sao trong đường dẫn có dấu cách, giống Program Files.
        windows_dir = self.root / 'Program Files' / 'course builder'
        windows_dir.mkdir(parents=True)
        copied = windows_dir / SCRIPT.name
        shutil.copy2(SCRIPT, copied)
        os.symlink(shutil.which('dirname'), self.bin / 'dirname')
        self.manager('powershell.exe')
        (self.bin / 'jq').unlink()
        result = subprocess.run(['/bin/sh', str(copied)], env=self.env, text=True,
                                capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                                        '-File', str(windows_dir / 'setup-dependencies.ps1')]])

    def test_help_and_bad_arguments_do_not_install(self):
        self.manager('apt-get')
        self.assertEqual(self.run_script('--help').returncode, 0)
        self.assertEqual(self.run_script('--unknown').returncode, 2)
        self.assertEqual(self.run_script('--check', 'extra').returncode, 2)
        self.assertEqual(self.calls(), [])


if __name__ == '__main__':
    unittest.main()
