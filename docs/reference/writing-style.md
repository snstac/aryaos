# AryaOS writing style

AryaOS uses pragmatic Simplified Technical English for technical text. This
style helps an operator understand each sentence after one read.

The style applies to:

- User and developer documentation.
- Procedures, warnings, and runbooks.
- Web pages and dashboard text.
- Login notices and operator commands.
- Errors, status messages, and actionable logs.

Marketing and brand writing use the AryaOS brand voice. Exact code, commands,
identifiers, paths, product names, and quoted errors do not change.

## Classify the text

Classify each passage before you write it.

Procedural text tells the reader what to do. Use the imperative form and a
maximum of 20 words per sentence. Put only one instruction in each sentence.

Descriptive text explains a fact. Use simple tenses and a maximum of 25 words
per sentence. Keep one topic in each paragraph. Use no more than six sentences
in a paragraph.

Do not mix instructions and descriptions in one passage. Put descriptive notes
outside the procedure.

## Write clear sentences

- Use active voice when you know who or what does the action.
- Use simple present, simple past, or simple future.
- Use `can`, `will`, or `must` for modal meaning.
- Do not use contractions or semicolons.
- Put a condition before its command: "If the service fails, read the log."
- Use a vertical list for more than two steps or related items.
- Keep articles such as "a," "an," "the," and "that."
- Remove filler that does not add a technical fact.
- Use American English spelling.

Use warnings for injury risks. Use cautions for equipment or data risks. Put
the command first. Then state the possible result.

## Use consistent terms

Use one term for each meaning.

| Term | Meaning |
|---|---|
| configuration | Saved values that control AryaOS behavior |
| setting | One named value in a configuration or an exact UI label |
| device | The physical computer that runs AryaOS |
| node | A device that participates in a network or discovery protocol |
| system | The running AryaOS software and operating system |
| service | A named systemd service or network service |
| make sure that | An instruction to establish or verify a state |
| examine | An instruction to look for faults or details |
| measure | An instruction to get a value |

UI labels and technical names stay exact. For example, documentation can refer
to a button named **Settings** without changing that label.

## Write useful errors

An actionable error gives this information in order:

1. State what failed.
2. State the cause if AryaOS knows it.
3. Tell the operator what to do next.

Do not change a quoted error from another program. Add AryaOS context before or
after the quoted text.

## Use lint directives

The style test reads these directives in Markdown and source comments:

- `simple-english: procedural` selects the 20-word limit.
- `simple-english: descriptive` selects the 25-word limit.
- `simple-english: ignore-next-line` exempts one exact line.
- `simple-english: off` starts an exempt block.
- `simple-english: on` ends an exempt block.

Use an exemption only for legal text, quoted text, license text, or brand copy.
The test rejects unmatched or unused directives.

## Review rules

The automated test finds objective problems. A reviewer must also make sure
that:

- Each procedure sentence contains one instruction.
- Each descriptive paragraph covers one topic.
- Conditions occur before commands.
- Pronouns have clear referents.
- Technical terms keep one meaning.
- Rewritten text preserves every technical fact.

This guide adapts the pragmatic mode of
[SimpleEnglish](https://github.com/AminBlg/SimpleEnglish). It does not establish
ASD-STE100 certification. Full compliance requires the official ASD-STE100
dictionary.

<!-- simple-english: off -->

SimpleEnglish is available under the MIT License:

Copyright (c) 2026 AminBlg

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

<!-- simple-english: on -->
