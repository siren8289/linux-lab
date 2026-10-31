import ipaddress
import unittest

VPC_CIDR = "10.0.0.0/16"
SUBNETS = [
    {"name": "public-a", "cidr": "10.0.1.0/24", "type": "public", "default_route": "igw"},
    {"name": "public-b", "cidr": "10.0.2.0/24", "type": "public", "default_route": "igw"},
    {"name": "private-app-a", "cidr": "10.0.11.0/24", "type": "private", "default_route": "nat"},
    {"name": "private-app-b", "cidr": "10.0.12.0/24", "type": "private", "default_route": "nat"},
    {"name": "private-db-a", "cidr": "10.0.21.0/24", "type": "database", "default_route": None},
    {"name": "private-db-b", "cidr": "10.0.22.0/24", "type": "database", "default_route": None},
]


def validate(vpc_cidr, subnets):
    vpc = ipaddress.ip_network(vpc_cidr)
    errors = []
    parsed = []
    expected_routes = {
        "public": "igw",
        "private": "nat",
        "database": None,
    }

    for subnet in subnets:
        net = ipaddress.ip_network(subnet["cidr"])
        if not net.subnet_of(vpc):
            errors.append(f"{subnet['name']}: {net} is outside {vpc}")
        expected = expected_routes[subnet["type"]]
        if subnet["default_route"] != expected:
            errors.append(
                f"{subnet['name']}: default route {subnet['default_route']!r}, expected {expected!r}"
            )
        parsed.append((subnet["name"], net))

    for index, (left_name, left) in enumerate(parsed):
        for right_name, right in parsed[index + 1 :]:
            if left.overlaps(right):
                errors.append(f"overlap: {left_name} {left} and {right_name} {right}")
    return errors


class VpcDesignTest(unittest.TestCase):
    def test_valid_design(self):
        self.assertEqual(validate(VPC_CIDR, SUBNETS), [])

    def test_overlap_detected(self):
        overlapped = [dict(item) for item in SUBNETS]
        overlapped[1] = {**overlapped[1], "cidr": "10.0.1.0/24"}
        errors = validate(VPC_CIDR, overlapped)
        self.assertTrue(any(item.startswith("overlap:") for item in errors))

    def test_wrong_route_detected(self):
        misrouted = [dict(item) for item in SUBNETS]
        misrouted[0] = {**misrouted[0], "default_route": "nat"}
        errors = validate(VPC_CIDR, misrouted)
        self.assertTrue(any("default route" in item for item in errors))

    def test_outside_vpc_detected(self):
        outside = [dict(item) for item in SUBNETS]
        outside[0] = {**outside[0], "cidr": "10.1.0.0/24"}
        errors = validate(VPC_CIDR, outside)
        self.assertTrue(any("outside" in item for item in errors))


if __name__ == "__main__":
    unittest.main(verbosity=2)
