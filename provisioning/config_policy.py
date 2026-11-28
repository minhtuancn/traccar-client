"""Pure validation policy for a future consent-based configuration channel.

No network, credentials, device lookup, tracking commands or persistence here.
"""
from types import MappingProxyType

RANGES = MappingProxyType({
    "interval": (15, 3600),
    "distance": (10, 1000),
    "heartbeat": (60, 3600),
    "sync_batch_size": (1, 100),
    "sync_batch_interval": (30, 3600),
    "heartbeat_max_age": (30, 900),
})
ENUMS = MappingProxyType({
    "accuracy": frozenset(("high", "medium", "low")),
    "sync_mode": frozenset(("instant", "batch", "offline")),
})


def validate_patch(payload, current_revision):
    """Reject unknown keys and stale revisions; return validated settings only."""
    if type(current_revision) is not int or current_revision < 0:
        raise ValueError("invalid current revision")
    if type(payload) is not dict or set(payload) != {"schema", "revision", "settings"}:
        raise ValueError("invalid envelope")
    if type(payload["schema"]) is not int or payload["schema"] != 1:
        raise ValueError("unsupported schema")
    revision = payload["revision"]
    if type(revision) is not int or not current_revision < revision <= 2**53 - 1:
        raise ValueError("invalid or stale revision")
    settings = payload["settings"]
    if type(settings) is not dict or not settings:
        raise ValueError("empty or invalid settings")
    for key, value in settings.items():
        if key in RANGES:
            lo, hi = RANGES[key]
            if type(value) is not int or not lo <= value <= hi:
                raise ValueError("integer setting out of range")
        elif key in ENUMS:
            if type(value) is not str or value not in ENUMS[key]:
                raise ValueError("invalid enum")
        elif key == "adaptive_tracking":
            if type(value) is not bool:
                raise ValueError("invalid boolean")
        else:
            raise ValueError("unsupported setting")
    return revision, dict(settings)
