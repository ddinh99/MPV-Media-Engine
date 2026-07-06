# C:\Users\Dai\Desktop\OriginalArkanoid\mpv_websocket_bridge.py
import socket
import hashlib
import base64
import struct
import threading
import sys

WEBSOCKET_PORT = 9002
MPV_TCP_PORT = 9001
MPV_HOST = '127.0.0.1'

def perform_handshake(client_socket):
    request = client_socket.recv(1024).decode('utf-8', errors='ignore')
    if "Upgrade: websocket" not in request:
        return False
    
    # Extract WebSocket Key
    key = ""
    for line in request.split('\r\n'):
        if line.startswith("Sec-WebSocket-Key:"):
            key = line.split(":")[1].strip()
            break
            
    if not key:
        return False
        
    # Calculate accept key
    guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    accept_key = base64.b64encode(
        hashlib.sha1((key + guid).encode('utf-8')).digest()
    ).decode('utf-8')
    
    response = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Accept: {}\r\n\r\n"
    ).format(accept_key)
    
    client_socket.send(response.encode('utf-8'))
    return True

def read_websocket_frame(client_socket):
    try:
        # Read header (first 2 bytes)
        header = client_socket.recv(2)
        if len(header) < 2:
            return None
            
        b1, b2 = header
        opcode = b1 & 0x0F
        masked = (b2 & 0x80) != 0
        payload_len = b2 & 0x7F
        
        if opcode == 8: # Connection close
            return None
            
        if payload_len == 126:
            ext_len = client_socket.recv(2)
            payload_len = struct.unpack(">H", ext_len)[0]
        elif payload_len == 127:
            ext_len = client_socket.recv(8)
            payload_len = struct.unpack(">Q", ext_len)[0]
            
        if masked:
            mask_key = client_socket.recv(4)
            
        raw_payload = bytearray()
        remaining = payload_len
        while remaining > 0:
            chunk = client_socket.recv(min(remaining, 4096))
            if not chunk:
                break
            raw_payload.extend(chunk)
            remaining -= len(chunk)
            
        if masked:
            # Unmask payload
            payload = bytearray(len(raw_payload))
            for i in range(len(raw_payload)):
                payload[i] = raw_payload[i] ^ mask_key[i % 4]
            return payload.decode('utf-8', errors='ignore')
        else:
            return raw_payload.decode('utf-8', errors='ignore')
    except Exception as e:
        print(f"Error reading frame: {e}")
        return None

def handle_web_client(client_socket, mpv_socket):
    print("[Bridge] Client connected from browser.")
    try:
        if not perform_handshake(client_socket):
            print("[Bridge] Handshake failed.")
            return
            
        print("[Bridge] Handshake completed successfully.")
        while True:
            msg = read_websocket_frame(client_socket)
            if msg is None:
                print("[Bridge] Client disconnected.")
                break
                
            if msg.strip():
                print(f"[Bridge] Forwarding: {msg.strip()}")
                # Forward directly to MPV via the TCP socket
                mpv_socket.sendall((msg + "\n").encode('utf-8'))
    except Exception as e:
        print(f"Client thread exception: {e}")
    finally:
        client_socket.close()

def run_bridge():
    print("==================================================")
    print(" MVP Sound Engine - WebSocket to MPV TCP Bridge")
    print("==================================================")
    
    # 1. Connect to MPV
    print(f"[MPV] Connecting to MPV at {MPV_HOST}:{MPV_TCP_PORT}...")
    try:
        mpv_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        mpv_socket.connect((MPV_HOST, MPV_TCP_PORT))
        print("[MPV] Connected successfully!")
    except Exception as e:
        print(f"\n[ERROR] Could not connect to MPV: {e}")
        print("Please start MPV first with the following arguments:")
        print(f"  mpv --input-ipc-server=tcp://0.0.0.0:{MPV_TCP_PORT} movie.mp4")
        sys.exit(1)
        
    # 2. Start WebSocket Server
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('127.0.0.1', WEBSOCKET_PORT))
        server.listen(5)
        print(f"[Bridge] Listening for Web App on ws://localhost:{WEBSOCKET_PORT}...")
    except Exception as e:
        print(f"\n[ERROR] Could not bind bridge server: {e}")
        mpv_socket.close()
        sys.exit(1)
        
    try:
        while True:
            client_sock, _ = server.accept()
            # Start client thread
            t = threading.Thread(target=handle_web_client, args=(client_sock, mpv_socket), daemon=True)
            t.start()
    except KeyboardInterrupt:
        print("\nStopping bridge...")
    finally:
        server.close()
        mpv_socket.close()

if __name__ == "__main__":
    run_bridge()
