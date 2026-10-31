import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 9000))
    server.listen(1)
    print("TCP server listening on 9000", flush=True)
    conn, addr = server.accept()
    with conn:
        print("Client:", addr)
        data = conn.recv(1024)
        conn.sendall(b"ACK:" + data)
