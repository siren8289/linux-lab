import socket

with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server:
    server.bind(("127.0.0.1", 9001))
    server.settimeout(3)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
        client.sendto(b"hello UDP", ("127.0.0.1", 9001))
    data, address = server.recvfrom(1024)
    print(data.decode(), address[0])
