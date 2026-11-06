#!/usr/bin/env python3
"""
Рекурсивно находит все .gd файлы и:
  copy   — копирует их в целевую папку (с сохранением структуры)
  concat — собирает всё содержимое в один файл

Примеры:
  python gd_tool.py copy ./project ./backup
  python gd_tool.py concat ./project -o all_scripts.txt
"""

import argparse
import shutil
from pathlib import Path


def iter_gd_files(root: Path):
    """Рекурсивно перебирает все .gd файлы, отсортированные по пути."""
    for path in sorted(root.rglob("*.gd")):
        if path.is_file():
            yield path


def copy_mode(src: Path, dst: Path) -> int:
    dst.mkdir(parents=True, exist_ok=True)
    count = 0
    for gd in iter_gd_files(src):
        rel = gd.relative_to(src)
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(gd, target)
        print(f"{gd}  ->  {target}")
        count += 1
    return count


def concat_mode(src: Path, out: Path) -> int:
    count = 0
    with out.open("w", encoding="utf-8") as f:
        for gd in iter_gd_files(src):
            f.write("\n" + "=" * 70 + "\n")
            f.write(f"# FILE: {gd}\n")
            f.write("=" * 70 + "\n\n")
            try:
                f.write(gd.read_text(encoding="utf-8"))
            except UnicodeDecodeError:
                # на случай не-UTF8 исходников
                f.write(gd.read_text(encoding="latin-1"))
            f.write("\n")
            count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description="Рекурсивная обработка .gd файлов")
    parser.add_argument("mode", choices=["copy", "concat"], help="режим работы")
    parser.add_argument("src", type=Path, help="папка-источник")
    parser.add_argument("dst", nargs="?", type=Path,
                        help="папка-назначение (для режима copy)")
    parser.add_argument("-o", "--output", type=Path, default=Path("all_gd_content.txt"),
                        help="выходной файл (для режима concat), по умолчанию all_gd_content.txt")
    args = parser.parse_args()

    if not args.src.is_dir():
        parser.error(f"Источник не найден: {args.src}")

    if args.mode == "copy":
        if not args.dst:
            parser.error("Для режима copy нужно указать папку-назначение")
        n = copy_mode(args.src, args.dst)
        print(f"\nСкопировано файлов: {n}")
    else:
        n = concat_mode(args.src, args.output)
        print(f"\nОбъединено файлов: {n} -> {args.output}")


if __name__ == "__main__":
    main()