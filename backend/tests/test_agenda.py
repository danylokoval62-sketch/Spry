"""Run: python -m pytest backend/tests  (or python backend/tests/test_agenda.py)."""

import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.ai import agenda  # noqa: E402


class FakeClient:
    """Replies with the given tool inputs, one per call."""

    def __init__(self, *inputs):
        self.inputs = list(inputs)

    def converse(self, **kw):
        call = {"toolUse": {"toolUseId": "t1", "name": "record_agenda", "input": self.inputs.pop(0)}}
        return {
            "output": {"message": {"role": "assistant", "content": [call]}},
            "stopReason": "tool_use",
            "usage": {"inputTokens": 100, "outputTokens": 10},
        }


def run(*inputs):
    client = FakeClient(*inputs)
    agenda._client = lambda: client
    return agenda.parse_agenda("text", date(2026, 10, 5), "Europe/Kyiv")


def test_valid():
    a, usage = run({"items": [{"topic": "Pricing", "minutes": 15}], "language": "uk"})
    assert a.items[0].owner is None and usage == {"input_tokens": 100, "output_tokens": 10}


def test_retry_then_ok_sums_usage():
    a, usage = run({"items": [{"topic": ""}], "language": "uk"}, {"items": [], "language": "uk"})
    assert a.items == [] and usage["input_tokens"] == 200


def test_invalid_twice_raises():
    bad = {"items": [{"topic": "x", "minutes": 9999}], "language": "en"}
    try:
        run(bad, bad)
    except agenda.AgendaParseError:
        return
    raise AssertionError("expected AgendaParseError")


def test_cost():
    assert agenda.cost_usd(agenda.PARSER_MODEL, {"input_tokens": 1e6, "output_tokens": 1e6}) == 6.0


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
    print("ok")
