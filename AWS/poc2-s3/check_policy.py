import json
from fnmatch import fnmatchcase

with open("policy.json", encoding="utf-8") as handle:
    policy = json.load(handle)


def permitted(action, resource):
    allowed = False
    for statement in policy["Statement"]:
        actions = statement["Action"]
        resources = statement["Resource"]
        if isinstance(actions, str):
            actions = [actions]
        if isinstance(resources, str):
            resources = [resources]
        action_match = any(fnmatchcase(action.lower(), item.lower()) for item in actions)
        resource_match = any(fnmatchcase(resource, item) for item in resources)
        if action_match and resource_match:
            if statement["Effect"] == "Deny":
                return False
            if statement["Effect"] == "Allow":
                allowed = True
    return allowed


resource = "arn:aws:s3:::aws-study-local/hello.txt"
assert permitted("s3:GetObject", resource)
assert not permitted("s3:PutObject", resource)
print("GetObject: ALLOW")
print("PutObject: DENY")
print("PASS")
