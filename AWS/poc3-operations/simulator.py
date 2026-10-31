from dataclasses import dataclass


@dataclass
class Backend:
    name: str
    healthy: bool


class LoadBalancer:
    def __init__(self, backends):
        self.backends = backends
        self.next_index = 0

    def route(self):
        healthy = [backend for backend in self.backends if backend.healthy]
        if not healthy:
            raise RuntimeError("No healthy targets")
        target = healthy[self.next_index % len(healthy)]
        self.next_index += 1
        return target.name


def scale(desired, cpu, minimum=2, maximum=4):
    if cpu > 70:
        return min(desired + 1, maximum)
    if cpu < 30:
        return max(desired - 1, minimum)
    return desired


def alarm(cpu, threshold=70):
    if cpu >= threshold:
        return "ALARM"
    return "OK"


def main():
    balancer = LoadBalancer(
        [
            Backend("EC2-A", True),
            Backend("EC2-B", True),
            Backend("EC2-C", False),
        ]
    )
    routed = [balancer.route() for _ in range(6)]
    print("[ALB]")
    print(routed)
    assert routed == ["EC2-A", "EC2-B", "EC2-A", "EC2-B", "EC2-A", "EC2-B"]
    assert "EC2-C" not in routed

    print("[AUTO SCALING]")
    desired = 2
    seen = []
    for cpu in (85, 90, 50, 20):
        desired = scale(desired, cpu)
        seen.append((cpu, desired))
        print(f"CPU={cpu}% desired={desired}")
    assert seen == [(85, 3), (90, 4), (50, 4), (20, 3)]
    assert scale(2, 10, minimum=2, maximum=4) == 2
    assert scale(4, 99, minimum=2, maximum=4) == 4

    print("[CLOUDWATCH ALARM]")
    for cpu in (85, 40):
        print(f"CPU {cpu}: {alarm(cpu)}")
    assert alarm(85) == "ALARM"
    assert alarm(40) == "OK"
    try:
        LoadBalancer([Backend("EC2-C", False)]).route()
        raise AssertionError("unhealthy-only pool should fail")
    except RuntimeError as error:
        assert str(error) == "No healthy targets"
    print("PASS: all tests")


if __name__ == "__main__":
    main()
