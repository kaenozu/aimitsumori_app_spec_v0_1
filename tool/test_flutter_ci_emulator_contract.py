from pathlib import Path

WORKFLOW = Path(__file__).parents[1] / ".github" / "workflows" / "flutter_ci.yml"

def main():
    workflow = WORKFLOW.read_text(encoding="utf-8")
    expected = "disk-size: 4G"
    if expected not in workflow:
        raise SystemExit("Android emulator userdata disk size is not runner-safe")
    if "-partition-size 4096" in workflow:
        raise SystemExit("Android emulator system partition override is not the userdata disk-size contract")
    print("flutter CI emulator contract: PASS")

if __name__ == "__main__":
    main()
