"""
DietAI 前端编译检查 + 分析脚本

用法:
    python tests/frontend_check.py
    python tests/frontend_check.py --fix

检查项:
    1. flutter pub get 依赖安装
    2. flutter analyze 静态分析
    3. 错误计数和分类
"""

import subprocess
import sys
import re
import argparse


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def run_cmd(cmd: str, cwd: str = None) -> tuple[int, str]:
    """运行命令并返回 (exit_code, output)"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True,
            cwd=cwd, timeout=300
        )
        return result.returncode, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return -1, "命令超时"
    except Exception as e:
        return -1, str(e)


def main():
    parser = argparse.ArgumentParser(description="DietAI 前端检查")
    parser.add_argument("--fix", action="store_true", help="自动修复（dart fix）")
    parser.add_argument("--cwd", default="f:\\project\\DietAI\\frontend_flutter", help="前端目录")
    args = parser.parse_args()

    cwd = args.cwd

    print(f"\n{Colors.BOLD}{'='*50}")
    print(f"  DietAI 前端编译检查")
    print(f"{'='*50}{Colors.RESET}\n")

    # 1. 依赖安装
    print(f"{Colors.BLUE}[1/3] 检查依赖...{Colors.RESET}")
    code, output = run_cmd("flutter pub get", cwd=cwd)
    if code == 0:
        print(f"  {Colors.GREEN}✓ 依赖安装成功{Colors.RESET}")
    else:
        print(f"  {Colors.RED}✗ 依赖安装失败{Colors.RESET}")
        print(output[:500])
        sys.exit(1)

    # 2. 自动修复（可选）
    if args.fix:
        print(f"\n{Colors.BLUE}[2/3] 自动修复...{Colors.RESET}")
        code, output = run_cmd("dart fix --apply", cwd=cwd)
        if code == 0:
            print(f"  {Colors.GREEN}✓ 自动修复完成{Colors.RESET}")
        else:
            print(f"  {Colors.YELLOW}⚠ 自动修复部分失败{Colors.RESET}")

    # 3. 静态分析
    step_label = "[2/3]" if not args.fix else "[3/3]"
    print(f"\n{Colors.BLUE}{step_label} 静态分析 (flutter analyze)...{Colors.RESET}")
    code, output = run_cmd("flutter analyze", cwd=cwd)

    # 解析分析结果
    errors = []
    warnings = []
    infos = []

    for line in output.split("\n"):
        line = line.strip()
        if "error •" in line or " - error •" in line:
            errors.append(line)
        elif "warning •" in line or " - warning •" in line:
            warnings.append(line)
        elif "info •" in line or " - info •" in line:
            infos.append(line)

    # 汇总
    print(f"\n{Colors.BOLD}分析结果:{Colors.RESET}")
    print(f"  {Colors.RED}错误 (error): {len(errors)}{Colors.RESET}")
    print(f"  {Colors.YELLOW}警告 (warning): {len(warnings)}{Colors.RESET}")
    print(f"  信息 (info): {len(infos)}")

    # 显示错误详情
    if errors:
        print(f"\n{Colors.RED}{Colors.BOLD}错误详情:{Colors.RESET}")
        for err in errors[:20]:
            print(f"  {err}")

    if warnings:
        print(f"\n{Colors.YELLOW}警告详情（前10条）:{Colors.RESET}")
        for w in warnings[:10]:
            print(f"  {w}")

    # 最终判断
    if errors:
        print(f"\n{Colors.RED}{Colors.BOLD}存在 {len(errors)} 个错误，请修复！{Colors.RESET}")
        sys.exit(1)
    else:
        print(f"\n{Colors.GREEN}{Colors.BOLD}无编译错误，前端代码检查通过！{Colors.RESET}")
        if warnings:
            print(f"{Colors.YELLOW}提示: 存在 {len(warnings)} 个警告，建议修复{Colors.RESET}")
        sys.exit(0)


if __name__ == "__main__":
    main()
