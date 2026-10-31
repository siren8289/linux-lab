import socket

with socket.create_connection(("127.0.0.1", 9000)) as client:
    client.sendall(b"hello")
    print(client.recv(1024).decode())
