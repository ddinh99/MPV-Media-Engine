# C:\Users\Dai\Desktop\OriginalArkanoid\test_ipc.py
import socket
import json
import time
import sys

MPV_HOST = '127.0.0.1'
MPV_PORT = 9001

def run_test():
    print("==================================================")
    print(" MPV IPC Simple Connection Test")
    print("==================================================")
    
    # 1. Connect to MPV
    print(f"Connecting to MPV at {MPV_HOST}:{MPV_PORT}...")
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((MPV_HOST, MPV_PORT))
        print("✓ Connected to MPV successfully!")
    except Exception as e:
        print(f"✗ Connection failed: {e}")
        print("\nPlease make sure MPV is running with this command:")
        print(f"  mpv --input-ipc-server=tcp://127.0.0.1:{MPV_PORT} \"C:\\path\\to\\movie.mp4\"")
        sys.exit(1)

    # Helper function to send command and read response
    def send_cmd(cmd_dict):
        cmd_str = json.dumps(cmd_dict) + "\n"
        print(f"\nSending: {cmd_str.strip()}")
        s.sendall(cmd_str.encode('utf-8'))
        
        # Read response (non-blocking simulation or small timeout)
        s.settimeout(1.0)
        try:
            response = s.recv(4096).decode('utf-8')
            print(f"Response from MPV: {response.strip()}")
        except socket.timeout:
            print("No response (timeout, which is normal for some commands)")

    # Test 1: Mute audio (visible feedback in MPV)
    print("\n--- Test 1: Muting audio for 3 seconds ---")
    send_cmd({"command": ["set_property", "mute", True]})
    
    time.sleep(3)
    
    # Test 2: Unmute audio
    print("\n--- Test 2: Unmuting audio ---")
    send_cmd({"command": ["set_property", "mute", False]})

    # Test 3: Apply a very simple volume filter
    print("\n--- Test 3: Applying simple volume filter (-10dB) ---")
    send_cmd({"command": ["set_property", "af", "lavfi=[volume=volume=-10dB]"]})
    
    time.sleep(3)
    
    # Test 4: Clear filters
    print("\n--- Test 4: Clearing all filters ---")
    send_cmd({"command": ["set_property", "af", ""]})

    print("\nClosing connection...")
    s.close()
    print("Test finished successfully!")

if __name__ == "__main__":
    run_test()
