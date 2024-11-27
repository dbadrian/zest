#!/usr/bin/env python
from pathlib import Path
import tempfile
import argparse
from typing import Any, List, Optional, Union
import subprocess
import venv
import logging
import shutil
import os
import pathlib
from string import Template

logger = logging.getLogger(__name__)

BASE_PATH = pathlib.Path(__file__).parent.resolve()

BUILD_VENV = "build_venv"

PACKAGE_NAME_TEMPLATE = Template('zest-${version}.pyz')
ENTRY_POINT = "main:main"
BACKEND_FILES = [
    "config",
    "favorites",
    "foods",
    "locale",
    "recipes",
    "shared",
    "shopping_lists",
    "tags",
    "units",
    "users",
    "zest",
    "manage.py",
    "main.py",
]


def run_call(call: Union[str, List[str]],
             cwd: Union[str, Path] = None,
             shell: bool = False,
             split_string: bool = False) -> subprocess.CompletedProcess:
    """Execute systemcall with subprocess, capture output."""
    logger.debug(f"subprocess call: {call}, cwd: {cwd}, shell: {shell}")
    if split_string and isinstance(call, str):
        call = call.split(" ")
    cwd = str(cwd) if cwd is not None else None
    return subprocess.run(call, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd, shell=shell)


def create_venv(base_path: Union[str, Path], name: str) -> Path:
    base_path = Path(base_path)
    venv_dir = base_path.joinpath(name)
    venv_builder = venv.EnvBuilder(with_pip=True, upgrade_deps=True)
    venv_builder.create(venv_dir)
    return venv_dir


def _git_call(cmd: str, cwd: Union[str, Path], shell: bool = False) -> str:
    ret = run_call(call=cmd, cwd=cwd, shell=shell)
    logger.debug(f"Git call ret: {ret}")
    ret.check_returncode()
    return ret.stdout.strip().decode("utf-8")


def get_git_repo_root_from_file(path: Path) -> Optional[Path]:
    """Gets the git repo root of current work dir"""
    return Path(_git_call("git rev-parse --show-toplevel", path, shell=True))


def get_latest_release_tag(path: Path) -> Optional[str]:
    try:
        return _git_call("git describe --tags $(git rev-list --tags='v[0-9].[0-9]*' --max-count=1)", path, shell=True)
    except subprocess.CalledProcessError:
        return None


def get_git_commit(path: Path) -> Optional[str]:
    return _git_call("git rev-parse --short HEAD", path, shell=True)


def git_worktree_checkout(repo_dir: Path, commit_ish: str, checkout_path: Path):
    return _git_call(f"git worktree add {checkout_path} {commit_ish}", repo_dir, shell=True)


def install_pip_packages(venv_path: Path,
                         packages: List[str] = None,
                         requirements_txt: Path = None,
                         target: str = None,
                         silent=True):

    p_python = str(venv_path.joinpath("bin", "python"))
    cmd = [p_python, "-m", "pip", "install"]
    if packages:
        cmd += packages
    elif requirements_txt:
        cmd += ["-r", str(requirements_txt)]
    else:
        # TODO: proper exception, not runtime
        raise RuntimeError("packages or from_requirements must be set")

    if target:
        cmd += ["--target", f"{target}/"]
    logger.debug(cmd)
    subprocess.check_call(cmd, stdout=open(os.devnull, 'wb') if silent else None)


def run_in_venv(venv_path, cmd, module: bool = True, cwd=None):
    if isinstance(cmd, str):
        cmd = cmd.split(" ")
    p_python = str(venv_path.joinpath("bin", "python"))
    call = [p_python]
    if module:
        call += ["-m"]
    call += cmd
    ret = run_call(" ".join(call), cwd=cwd, shell=True)
    ret.check_returncode()

    return ret.stdout.decode("utf-8")


def setup_virtual_python_environment(tmp_dir):
    venv = create_venv(tmp_dir, BUILD_VENV)
    install_pip_packages(venv, ["poetry", "shiv"])
    return venv


def export_package_list_from_poetry(venv, path_to_pyproject: Path, output_file: Path):
    call = f"poetry export -f requirements.txt --without-hashes -o {str(output_file)}"
    return run_in_venv(venv, call, module=True, cwd=path_to_pyproject)


def get_package_version(args: argparse.Namespace, repo_dir: Path):
    # Determine version to build:
    if args.latest:
        pkg_version = get_git_commit(repo_dir)
    elif args.release:
        pkg_version = get_latest_release_tag(repo_dir)
    elif args.commit_ish:
        pkg_version = args.commit_ish

    if pkg_version is None:
        raise RuntimeError("No valid pkg-version found. Use other setting")

    return pkg_version


def copy_files_and_folders(files_and_folders: List[Union[Path, str]],
                           dst: Union[Path, str],
                           src_prefix: Union[Path, str] = None) -> None:
    dst = Path(dst)
    for f in files_and_folders:
        if src_prefix:
            f = Path(src_prefix).joinpath(f)

        if f.is_dir():
            p = dst.joinpath(f.stem)
            logger.debug(f"Copying '{f}' to {p}")
            shutil.copytree(f, p)
        else:
            logger.debug(f"Copying '{f}' to {dst}")
            shutil.copy2(f, dst)


def get_shiv_package_name(version):
    return PACKAGE_NAME_TEMPLATE.substitute(version=version)


def build_shiv_package(venv, site_packages: Union[Path, str], version: str, python_path: str, entry_point: str,
                       output_folder: Union[Path, str]):
    output = output_folder.joinpath(get_shiv_package_name(version))

    # add a file for build version
    with open(site_packages.joinpath("zest", "version.py"), "a") as f:
        f.write(f"build_version = '{version}'")

    call = f"shiv --site-packages {str(site_packages)} --compressed -p '{python_path}' -o {output} -e {entry_point}"
    run_in_venv(venv, cmd=call, module=True)


def build_package(args, tmp_dir):
    repo_dir = get_git_repo_root_from_file(BASE_PATH)
    logger.debug(f"Found repo root at `{repo_dir}`")
    pkg_ver = get_package_version(args, repo_dir)

    logger.info(f"Building package version: {pkg_ver}")
    git_worktree_checkout(repo_dir, pkg_ver, tmp_dir.joinpath("repo"))

    logger.info("Creating virtual environment")
    venv = setup_virtual_python_environment(tmp_dir)

    logger.info("Generating distribution")
    export_package_list_from_poetry(venv, repo_dir.joinpath('backend'), tmp_dir.joinpath("requirements.txt"))
    target_folder = tmp_dir.joinpath("repo", "backend", "dist")
    target_folder.mkdir()
    install_pip_packages(venv, requirements_txt=tmp_dir.joinpath("requirements.txt"), target=str(target_folder))

    # copy required backend files
    copy_files_and_folders(BACKEND_FILES, target_folder, repo_dir.joinpath('backend'))

    # build the package with shiv in the request output folder
    logger.info(f"Building Shiv package: '{args.output_path.joinpath(get_shiv_package_name(pkg_ver))}'")
    build_shiv_package(venv,
                       target_folder,
                       version=pkg_ver,
                       python_path=args.python,
                       entry_point=ENTRY_POINT,
                       output_folder=args.output_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Zest')
    parser.add_argument("--python", type=Path, help="Path to python executable of desired version.", required=True)
    parser.add_argument("--output-path", type=Path, help="Output path")
    parser.add_argument('--verbose', '-v', action='store_true', help="Enable debug output")

    version_parser = parser.add_mutually_exclusive_group(required=True)
    version_parser.add_argument("--commit-ish", type=str, help="Specific tag or commit to build")
    version_parser.add_argument("--release", action="store_true", help="If set, then build newest tag")
    version_parser.add_argument("--latest", action="store_true", help="If set, just build current branch latest")

    args = parser.parse_args()

    # -v: info
    # -vv: debug
    args.verbose = 20 - (10 * args.verbose) if args.verbose > 0 else 20

    logging.basicConfig(level=args.verbose,
                        format='%(asctime)s %(levelname)s: %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_dir = Path(tmp_dir)
        logger.debug(f"Created temporary directory (will be cleaned up) at: {tmp_dir}")
        build_package(args, tmp_dir)
