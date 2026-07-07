
# Flutter CLI Rules
Always use the full path to flutter when providing commands to the user or running terminal commands: c:\Users\Dai\dev\flutter\bin\flutter.bat instead of just lutter.

# Running and Building Rules
1. NEVER run `flutter run` directly via the agent terminal/background tools for Windows desktop apps, because the GUI will launch invisibly in the background session. Always instruct the user to run it in their own terminal or double-click the `run_app.bat` script.
2. ALWAYS ensure zombie processes are killed before building or running. The ghost processes `MPV_Sound_Engine.exe` and `dart.exe` often stay alive and lock the executable causing LNK1168 errors. Use the provided `run_app.bat` which handles cleanup.
3. If you (the agent) need to verify that the app builds successfully, strictly use `flutter build windows` and do NOT run the executable.
