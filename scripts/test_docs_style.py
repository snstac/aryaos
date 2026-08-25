#!/usr/bin/env python3
"""Check active AryaOS technical text for objective Simple English rules."""

from __future__ import annotations

from dataclasses import dataclass
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]

EXCLUDED_DOCS = {
    Path("docs/agent-handoff.md"),
    Path("docs/brand/VENDORED.md"),
    Path("docs/brand/fonts/THIRD_PARTY_NOTICES.md"),
    Path("docs/launch/aos2/announcement.md"),
    Path("docs/launch/aos2/claims-ledger.md"),
    Path("docs/launch/aos2/github-release-body.md"),
    Path("docs/launch/aos2/publication-checklist.md"),
    Path("docs/launch/aos2/social-and-email.md"),
    Path("docs/plans/dev-device-discovery.md"),
    Path("docs/purchase.md"),
}

OPERATOR_FILES = (
    Path("shared_files/aryaos/html/index.html"),
    Path("shared_files/aryaos/html/js/portal-landing.js"),
    Path("shared_files/aryaos/patch-cockpit-aryaos-dp"),
    Path("shared_files/aryaos/README-aryaos.txt"),
    Path("shared_files/aryaos/issue"),
    Path("shared_files/aryaos/issue.net"),
    Path("shared_files/aryaos/motd"),
    Path("shared_files/node-red/aryaos_flows.json"),
    Path("shared_files/aryaos/aryaos-update"),
    Path("shared_files/aryaos/aryaos-support-bundle"),
    Path("shared_files/aryaos/aryaos-set-nodered-password"),
    Path("shared_files/aryaos/aryaos-sdr"),
    Path("shared_files/aryaos/aryaos-role"),
    Path("shared_files/aryaos/aryaos-import-tak-dp"),
    Path("shared_files/aryaos/aryaos-config-backup"),
    Path("shared_files/aryaos/aryaos-factory-reset"),
    Path("shared_files/aryaos/aryaos-zeroize"),
    Path("shared_files/aryaos/aryaos-firstboot.sh"),
    Path("shared_files/aryaos/aryaos-health"),
)

LEGAL_NOTICE_FILES = {
    Path("shared_files/aryaos/issue"),
    Path("shared_files/aryaos/issue.net"),
    Path("shared_files/aryaos/motd"),
}

FORBIDDEN_PUNCTUATION = {
    "\N{EM DASH}": "em dash",
    "\N{EN DASH}": "en dash",
    "\N{HORIZONTAL ELLIPSIS}": "ellipsis",
    "\N{RIGHT SINGLE QUOTATION MARK}": "curly apostrophe",
    "\N{RIGHTWARDS ARROW}": "right arrow",
    "\N{MULTIPLICATION SIGN}": "multiplication sign",
}

FORBIDDEN_PATTERNS = (
    (re.compile(r"\b(?:should|would|might|could)\b", re.IGNORECASE), "ambiguous modal"),
    (re.compile(r"\bmay\b"), "ambiguous modal"),
    (re.compile(r"\b(?:has|have) been\b", re.IGNORECASE), "present perfect"),
    (re.compile(r"\b\w+'(?:ll|re|ve|d|m|t)\b", re.IGNORECASE), "contraction"),
    (
        re.compile(
            r",\s+(?:making|allowing|causing|resulting|leaving|providing|"
            r"ensuring|letting|forcing|destroying)\b",
            re.IGNORECASE,
        ),
        "dangling -ing clause",
    ),
    (
        re.compile(
            r"\b(?:at a glance|out of the box|simply|seamless(?:ly)?|"
            r"revolutionary|next-generation|empowering|actionable insights?|"
            r"exciting possibilities|delve|robust|comprehensive|leverage|"
            r"in this guide|important to note|worth noting|that's it|"
            r"what you'll see|everything you need|in order to|prior to|"
            r"in the event that|utili[sz]e)\b",
            re.IGNORECASE,
        ),
        "filler or disfavored phrase",
    ),
)

INLINE_CODE = re.compile(r"`[^`]*`")
MARKDOWN_LABEL = re.compile(r"\*\*[^*]+\*\*")
MARKDOWN_LINK = re.compile(r"!?\[([^]]*)\]\([^)]*\)")
HTML_TAG = re.compile(r"<[^>]+>")
WORD = re.compile(r"\b[\w]+(?:[-'][\w]+)*\b", re.UNICODE)
SENTENCE = re.compile(r"[^.!?]+(?:[.!?]+(?=\s|$)|$)")
DIRECTIVE = re.compile(
    r"simple-english:\s*(procedural|descriptive|ignore-next-line|off|on)"
)


@dataclass(frozen=True)
class Passage:
    path: Path
    line: int
    mode: str
    text: str


def active_docs() -> list[Path]:
    paths = [ROOT / "README.md", ROOT / "AGENTS.md"]
    paths.extend(sorted((ROOT / "docs").rglob("*.md")))
    return [path for path in paths if path.relative_to(ROOT) not in EXCLUDED_DOCS]


def clean_markdown(text: str) -> str:
    text = re.sub(r'^\s*!!!\s+\w+(?:\s+"[^"]+")?\s*', "", text)
    text = INLINE_CODE.sub(" TECHNICAL_NAME ", text)
    text = MARKDOWN_LABEL.sub(" LABEL ", text)
    text = MARKDOWN_LINK.sub(r"\1", text)
    text = HTML_TAG.sub(" ", text)
    text = re.sub(r"^\s*(?:[-*+] |\d+[.)] )", "", text)
    text = re.sub(r"[*_~]", "", text)
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def markdown_passages(path: Path) -> tuple[list[Passage], list[str]]:
    passages: list[Passage] = []
    directive_errors: list[str] = []
    mode = "descriptive"
    fenced = False
    disabled = False
    ignore_next = False
    buffer: list[str] = []
    start_line = 1
    buffer_mode = mode

    def flush() -> None:
        nonlocal buffer
        if buffer:
            text = clean_markdown(" ".join(buffer))
            if text:
                passages.append(Passage(path, start_line, buffer_mode, text))
            buffer = []

    lines = path.read_text(encoding="utf-8").splitlines()
    for number, raw in enumerate(lines, 1):
        stripped = raw.strip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            flush()
            fenced = not fenced
            continue
        if fenced:
            continue

        directive_match = DIRECTIVE.search(raw)
        if directive_match:
            flush()
            directive = directive_match.group(1)
            if directive == "off":
                if disabled:
                    directive_errors.append(f"{path.relative_to(ROOT)}:{number}: nested off directive")
                disabled = True
            elif directive == "on":
                if not disabled:
                    directive_errors.append(f"{path.relative_to(ROOT)}:{number}: unmatched on directive")
                disabled = False
            elif directive == "ignore-next-line":
                if ignore_next:
                    directive_errors.append(f"{path.relative_to(ROOT)}:{number}: unused ignore directive")
                ignore_next = True
            else:
                mode = directive
            continue
        if disabled:
            continue
        if ignore_next:
            if stripped:
                ignore_next = False
            continue
        if not stripped or stripped.startswith(('#', '|', '<div', '</div', '{!')):
            flush()
            continue
        if re.match(r"^\s*(?:\d+[.)]|!!!\s+(?:warning|danger|caution))\b", raw, re.IGNORECASE):
            flush()
            buffer_mode = "procedural"
            start_line = number
            buffer = [raw]
            flush()
            continue
        if re.match(r"^\s*[-*+]\s+", raw):
            flush()
            buffer_mode = mode
            start_line = number
            buffer = [raw]
            flush()
            continue
        if not buffer:
            start_line = number
            buffer_mode = mode
        buffer.append(raw)
    flush()
    if fenced:
        directive_errors.append(f"{path.relative_to(ROOT)}: unclosed code fence")
    if disabled:
        directive_errors.append(f"{path.relative_to(ROOT)}: unmatched off directive")
    if ignore_next:
        directive_errors.append(f"{path.relative_to(ROOT)}: unused ignore directive")
    return passages, directive_errors


def sentence_words(sentence: str) -> int:
    # STE counts parenthetical explanations, quoted labels, and values with
    # their units as one word each.
    sentence = re.sub(r"\([^()]*\)", " PARENTHETICAL ", sentence)
    sentence = re.sub(r'"[^"\n]+"', " QUOTED_TEXT ", sentence)
    sentence = re.sub(
        r"\b\d+(?:\.\d+)?\s*(?:B|KB|MB|GB|TB|Hz|kHz|MHz|GHz|ms|s|min|hours?|days?|%)\b",
        " VALUE ",
        sentence,
        flags=re.IGNORECASE,
    )
    return len(WORD.findall(sentence))


def passage_violations(passage: Passage) -> list[str]:
    failures: list[str] = []
    rel = passage.path.relative_to(ROOT)
    for pattern, name in FORBIDDEN_PATTERNS:
        match = pattern.search(passage.text)
        if match:
            failures.append(f"{rel}:{passage.line}: {name}: {match.group(0)}")
    if ";" in passage.text:
        failures.append(f"{rel}:{passage.line}: semicolon")
    limit = 20 if passage.mode == "procedural" else 25
    for sentence in SENTENCE.findall(passage.text):
        count = sentence_words(sentence)
        if count > limit:
            sample = sentence.strip().replace("\n", " ")
            failures.append(
                f"{rel}:{passage.line}: {passage.mode} sentence has {count} words "
                f"(limit {limit}): {sample}"
            )
    return failures


class VisibleHTML(HTMLParser):
    """Collect visible HTML text and accessibility labels."""

    def __init__(self) -> None:
        super().__init__()
        self.values: list[str] = []
        self.hidden_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style", "svg"}:
            self.hidden_depth += 1
        for key, value in attrs:
            if key in {"aria-label", "placeholder", "title"} and value:
                self.values.append(value)

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style", "svg"} and self.hidden_depth:
            self.hidden_depth -= 1

    def handle_data(self, data: str) -> None:
        if not self.hidden_depth and data.strip():
            self.values.append(data.strip())


def operator_strings(path: Path) -> list[str]:
    source = path.read_text(encoding="utf-8")
    if path.suffix == ".json":
        data = json.loads(source)
        values: list[str] = []
        for item in data:
            for key in ("label", "info", "tooltip", "format"):
                value = item.get(key)
                if isinstance(value, str) and value.strip():
                    if "<" in value:
                        parser = VisibleHTML()
                        parser.feed(value)
                        values.extend(parser.values)
                    else:
                        values.append(value)
        return values
    if path.suffix == ".html":
        parser = VisibleHTML()
        parser.feed(source)
        return parser.values
    if path.name in {"README-aryaos.txt", "issue", "issue.net", "motd"}:
        return [line.strip() for line in source.splitlines() if line.strip()]

    # UI JavaScript and the Cockpit overlay keep copy in quoted literals.
    values = []
    for match in re.finditer(r"(?P<q>['\"])(?P<v>(?:\\.|(?!\1).)*)\1", source):
        value = match.group("v")
        if re.search(r"[A-Za-z]{2,}\s+[A-Za-z]{2,}", value):
            values.append(value.replace(r"\n", " "))
    return values


class DocsStyleTestCase(unittest.TestCase):
    def test_active_text_uses_simple_english(self):
        failures: list[str] = []
        for path in active_docs():
            passages, directive_errors = markdown_passages(path)
            failures.extend(directive_errors)
            for passage in passages:
                failures.extend(passage_violations(passage))
        self.assertEqual([], failures)

    def test_active_docs_use_plain_ascii_punctuation(self):
        failures = []
        for path in active_docs():
            source = path.read_text(encoding="utf-8")
            for character, name in FORBIDDEN_PUNCTUATION.items():
                if character in source:
                    failures.append(f"{path.relative_to(ROOT)}: {name}")
        self.assertEqual([], failures)

    def test_operator_copy_avoids_banned_constructs(self):
        failures = []
        for relative in OPERATOR_FILES:
            path = ROOT / relative
            for value in operator_strings(path):
                if relative in LEGAL_NOTICE_FILES or "restricted to authorized users" in value:
                    continue
                for pattern, name in FORBIDDEN_PATTERNS:
                    match = pattern.search(value)
                    if match:
                        failures.append(f"{relative}: {name}: {match.group(0)}: {value}")
                limit = 20 if re.search(r"\b(?:failed|error|unavailable)\b", value, re.I) else 25
                for sentence in SENTENCE.findall(value):
                    count = sentence_words(sentence)
                    if count > limit:
                        failures.append(
                            f"{relative}: operator sentence has {count} words "
                            f"(limit {limit}): {sentence.strip()}"
                        )
        self.assertEqual([], failures)

    def test_markdown_parser_honors_modes_and_untouchables(self):
        fixture = ROOT / "scripts" / "fixtures" / "simple-english-sample.md"
        passages, errors = markdown_passages(fixture)
        self.assertEqual([], errors)
        self.assertEqual(["procedural", "descriptive"], [item.mode for item in passages])
        self.assertIn("TECHNICALNAME", passages[0].text)
        self.assertNotIn("quoted text can use anything", " ".join(item.text for item in passages))


if __name__ == "__main__":
    unittest.main()
