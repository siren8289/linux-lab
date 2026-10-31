import ipaddress
import socket
import sys


def check_subnet(cidr):
    network = ipaddress.ip_network(cidr, strict=False)
    print("[SUBNET]")
    print("Network:", network.network_address)
    print("Mask:", network.netmask)
    print("Total addresses:", network.num_addresses)


def check_dns(host):
    print("\n[DNS]")
    addresses = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
    ips = sorted({item[4][0] for item in addresses})
    for ip in ips:
        print("Resolved:", ip)


def check_tcp(host, port):
    print("\n[TCP]")
    try:
        with socket.create_connection((host, port), timeout=3):
            print(f"CONNECTED {host}:{port}")
            return True
    except OSError as error:
        print(f"FAILED {host}:{port}: {error}")
        return False


def main():
    check_subnet("192.168.10.130/26")
    check_dns("localhost")
    success = check_tcp("127.0.0.1", 8080)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
