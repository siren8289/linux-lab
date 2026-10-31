import ipaddress

vpc = ipaddress.ip_network("10.0.0.0/16")
subnets = [
    ipaddress.ip_network("10.0.1.0/24"),
    ipaddress.ip_network("10.0.2.0/24"),
    ipaddress.ip_network("10.0.11.0/24"),
    ipaddress.ip_network("10.0.12.0/24"),
    ipaddress.ip_network("10.0.21.0/24"),
    ipaddress.ip_network("10.0.22.0/24"),
]

for subnet in subnets:
    assert subnet.subnet_of(vpc), "Outside VPC"
    print(subnet, "usable:", subnet.num_addresses - 5)

for index, first in enumerate(subnets):
    for second in subnets[index + 1 :]:
        assert not first.overlaps(second), "CIDR overlap"

print("PASS: valid VPC subnet design")

print("[AWS reserved address examples]")
for prefix in (24, 26, 28):
    network = ipaddress.ip_network(f"10.0.1.0/{prefix}")
    print(
        f"/{prefix} total={network.num_addresses} "
        f"aws_usable={network.num_addresses - 5}"
    )
