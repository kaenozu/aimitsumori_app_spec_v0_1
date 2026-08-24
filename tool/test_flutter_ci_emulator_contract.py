from pathlib import Path

WORKFLOW = Path(__file__).parents[1] / ".github" / "workflows" / "flutter_ci.yml"

def main():
    workflow = WORKFLOW.read_text(encoding="utf-8")
    expected = "emulator-options: -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -partition-size 4096"
    if expected not in workflow:
        raise SystemExit("Android emulator userdata partition is not runner-safe")
    print("flutter CI emulator contract: PASS")

if __name__ == "__main__":
    main()
