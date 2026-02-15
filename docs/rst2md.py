#!/usr/bin/env python3
"""Convert keaddns.rst to keaddns.md using pandoc + post-processing.

Usage: python3 docs/rst2md.py
"""

import re
import subprocess
import sys
from pathlib import Path


def pandoc_convert(rst_path: Path) -> str:
    """Run pandoc to convert RST to GFM markdown."""
    result = subprocess.run(
        ["pandoc", "-f", "rst", "-t", "gfm", "--wrap=none", str(rst_path)],
        capture_output=True, text=True, check=True,
    )
    return result.stdout


def remove_contents_block(text: str) -> str:
    """Remove the RST contents directive artifact."""
    return re.sub(
        r'<div class="contents"[^>]*>\s*\n\s*Index\s*\n\s*</div>\s*\n*',
        '', text
    )


def convert_tabs(text: str) -> str:
    """Convert <div class="tabs">/<div class="tab"> to ### headings."""
    # Remove outer tabs wrapper
    text = re.sub(r'<div class="tabs">\s*\n*', '', text)
    # Convert tab divs: <div class="tab">\n\nTab Name\n -> ### Tab Name\n
    text = re.sub(
        r'<div class="tab">\s*\n\n(.+?)\n',
        lambda m: f'### {m.group(1).strip()}\n',
        text
    )
    # Remove closing </div> tags
    text = re.sub(r'\n*</div>\s*\n*', '\n\n', text)
    return text


def convert_admonition_divs(text: str) -> str:
    """Convert <div class="attention/warning/caution"> blocks to GFM alerts."""
    # First, strip all <div class="title">...\n</div> blocks inside admonitions
    text = re.sub(
        r'<div class="title">\s*\n*\s*\w+\s*\n*\s*</div>\s*\n*',
        '', text
    )

    # Now match admonition divs (no more nested divs to confuse the regex)
    admonition_types = 'attention|warning|caution|danger|important'

    def replace_admonition(m):
        admonition_type = m.group(1).upper()
        content = m.group(2).strip()
        type_map = {
            'ATTENTION': 'WARNING',
            'CAUTION': 'CAUTION',
            'WARNING': 'WARNING',
            'DANGER': 'CAUTION',
            'IMPORTANT': 'IMPORTANT',
        }
        gfm_type = type_map.get(admonition_type, 'WARNING')
        lines = content.split('\n')
        quoted = '\n'.join(f'> {line}' if line.strip() else '>' for line in lines)
        return f'> [!{gfm_type}]\n{quoted}'

    text = re.sub(
        rf'<div class="({admonition_types})">\s*\n(.*?)\n\s*</div>',
        replace_admonition,
        text,
        flags=re.DOTALL,
    )
    return text


def convert_html_tables(text: str) -> str:
    """Convert HTML <table> blocks to pipe tables."""
    def html_table_to_pipe(m):
        html = m.group(0)
        # Extract headers
        headers = re.findall(r'<th>(.*?)</th>', html, re.DOTALL)
        headers = [re.sub(r'<[^>]+>', '', h).strip() for h in headers]
        # Extract rows
        rows = re.findall(r'<tr>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*</tr>', html, re.DOTALL)
        pipe_rows = []
        for col1, col2 in rows:
            # Clean HTML from cells
            col1 = html_to_md(col1)
            col2 = html_to_md(col2)
            pipe_rows.append(f'| {col1} | {col2} |')

        header_line = f'| {" | ".join(headers)} |'
        sep_line = '|' + '|'.join('-' * (len(h) + 2) for h in headers) + '|'
        return header_line + '\n' + sep_line + '\n' + '\n'.join(pipe_rows)

    return re.sub(r'<table>.*?</table>', html_table_to_pipe, text, flags=re.DOTALL)


def html_to_md(html: str) -> str:
    """Convert inline HTML to markdown."""
    s = html.strip()
    # <strong>text</strong> -> **text**
    s = re.sub(r'<strong>(.*?)</strong>', r'**\1**', s)
    # <code>text</code> -> `text`
    s = re.sub(r'<code[^>]*>(.*?)</code>', r'`\1`', s)
    # <p>text</p> -> text
    s = re.sub(r'<p>(.*?)</p>', r'\1', s, flags=re.DOTALL)
    # <ul><li>...</li></ul> -> inline list
    items = re.findall(r'<li>(.*?)</li>', s, re.DOTALL)
    if items:
        item_text = ' '.join(f'**{item.strip()}**' if i == 0 else item.strip()
                             for i, item in enumerate(items))
        # Rebuild as a simple inline list
        clean_items = []
        for item in items:
            item = re.sub(r'<[^>]+>', '', item).strip()
            clean_items.append(item)
        s = re.sub(r'<ul>.*?</ul>', ' '.join(f'- {it}' for it in clean_items), s, flags=re.DOTALL)
    # Remove remaining HTML tags
    s = re.sub(r'<[^>]+>', '', s)
    # Collapse whitespace
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def fix_menuselection(text: str) -> str:
    """Fix menuselection artifacts."""
    # <code class="interpreted-text" role="menuselection">X --> Y</code>
    text = re.sub(
        r'<code class="interpreted-text"\s+role="menuselection">(.*?)</code>',
        lambda m: '**' + m.group(1).replace('&gt;', '>') + '**',
        text,
    )
    return text


def fix_title_ref(text: str) -> str:
    """Fix title-ref artifacts in various pandoc output formats."""
    # Pattern: \` <span class="title-ref">text</span>\`
    text = re.sub(
        r"""\\\`\s*<span class="title-ref">(.*?)</span>\s*\\\`""",
        r'`\1`',
        text,
    )
    # Pattern in table cells: **Qualifying suffix** \` | <span ...>text</span>\` |
    # This appears when RST has odd backtick placement in tables
    text = re.sub(
        r"""\*\*Qualifying suffix\*\*\s*\\\`\s*\|\s*<span class="title-ref">(.*?)</span>\\\`\s*\|""",
        r'**Qualifying suffix** | `\1` |',
        text,
    )
    # Catch any remaining <span class="title-ref"> artifacts
    text = re.sub(
        r'<span class="title-ref">(.*?)</span>',
        r'`\1`',
        text,
    )
    return text


def fix_api_tables(text: str) -> str:
    """Fix mangled API table rows where {uuid} broke pandoc's table parsing."""
    # Fix header: \*\*Method -> **Method**
    text = re.sub(r'\\\*\\\*Method\s*\|\s*\\\*\\\*\s*\*\*Description\*\*',
                  '**Method** | **Description**', text)
    # Fix broken rows like:
    # | \`\`/api/.../getSubnetDdns/{uuid | }\`\` GET | Get a DHCPv4 DDNS assignment |
    # | \`\`/api/.../getForwardZone/{uui | d}\`\` GE | T Get a forward zone |
    def fix_broken_row(m):
        full = m.group(0)
        # Try to reconstruct: endpoint, method, description
        match = re.match(
            r'\|\s*\\\`\\\`(/[^|]+?)\s*\|\s*([^|]+?)\\\`\\\`\s+([A-Z]+)\s*\|\s*([A-Z]*)\s*(.*?)\s*\|',
            full
        )
        if match:
            endpoint = match.group(1).strip() + match.group(2).strip()
            method = match.group(3) + match.group(4)
            desc = match.group(5).strip()
            return f'| `{endpoint}` | {method} | {desc} |'
        return full

    text = re.sub(r'\|[^\n]*\\\`\\\`/api/[^\n]*\|', fix_broken_row, text)

    # Also fix rows where pandoc merged method into description:
    # | `/api/.../getSubnetDdns/{uuid}` | GETG | et a DHCPv4 DDNS assignment |
    def fix_merged_method(m):
        endpoint = m.group(1)
        merged = m.group(2).strip()
        rest = m.group(3).strip()
        # Split merged method: "GETG" -> "GET", "G" or "POST" -> "POST", "T"
        for method in ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']:
            if merged.startswith(method) and len(merged) > len(method):
                leftover = merged[len(method):]
                desc = leftover + rest
                # Capitalize first letter of description
                desc = desc[0].upper() + desc[1:] if desc else rest
                return f'| `{endpoint}` | {method} | {desc} |'
        return m.group(0)

    text = re.sub(
        r'\|\s*`(/api/[^`]+)`\s*\|\s*([A-Z]{4,6})\s*\|\s*(.*?)\s*\|',
        fix_merged_method,
        text,
    )
    return text


def fix_indented_code_blocks(text: str) -> str:
    """Convert 4-space indented code blocks to fenced code blocks."""
    lines = text.split('\n')
    result = []
    i = 0
    while i < len(lines):
        # Look for indented code blocks (4+ spaces after a blank line)
        if (i > 0 and lines[i - 1].strip() == '' and
                lines[i].startswith('    ') and not lines[i].startswith('    -') and
                not lines[i].startswith('    >') and
                not lines[i].lstrip().startswith('|') and
                not lines[i].lstrip().startswith('-')):
            # Collect all indented lines
            code_lines = []
            while i < len(lines) and (lines[i].startswith('    ') or lines[i].strip() == ''):
                if lines[i].strip() == '' and i + 1 < len(lines) and not lines[i + 1].startswith('    '):
                    break
                code_lines.append(lines[i][4:] if lines[i].startswith('    ') else '')
                i += 1
            # Remove trailing blank lines from code block
            while code_lines and code_lines[-1].strip() == '':
                code_lines.pop()
            # Strip common leading whitespace from code lines
            non_empty = [l for l in code_lines if l.strip()]
            if non_empty:
                min_indent = min(len(l) - len(l.lstrip()) for l in non_empty)
                if min_indent > 0:
                    code_lines = [l[min_indent:] if l.strip() else '' for l in code_lines]
            result.append('```')
            result.extend(code_lines)
            result.append('```')
        else:
            result.append(lines[i])
            i += 1
    return '\n'.join(result)


def fix_troubleshooting_headings(text: str) -> str:
    """Fix troubleshooting subsection headings from #### to ###."""
    # Under ## Troubleshooting, subsections should be ###
    in_troubleshooting = False
    lines = text.split('\n')
    result = []
    for line in lines:
        if line.startswith('## Troubleshooting'):
            in_troubleshooting = True
        elif line.startswith('## ') and in_troubleshooting:
            in_troubleshooting = False
        if in_troubleshooting and line.startswith('#### '):
            line = '### ' + line[5:]
        result.append(line)
    return '\n'.join(result)


def convert_gfm_alerts(text: str) -> str:
    """Convert GFM alerts (> [!NOTE]) to simple bold blockquotes for broader compatibility."""
    def replace_alert(m):
        alert_type = m.group(1)
        content = m.group(2)
        # Capitalize: NOTE -> Note, TIP -> Tip, WARNING -> Warning, etc.
        label = alert_type.capitalize()
        # Strip "> " prefix from each content line
        lines = []
        for line in content.split('\n'):
            stripped = re.sub(r'^>\s?', '', line)
            lines.append(stripped)
        # Remove trailing empty lines
        while lines and not lines[-1].strip():
            lines.pop()
        # Join all content, re-wrap as blockquote with label
        body = ' '.join(line for line in lines if line.strip())
        return f'> **{label}:** {body}\n'

    text = re.sub(
        r'> \[!(NOTE|TIP|WARNING|CAUTION|IMPORTANT)\]\n((?:>.*\n?)*)',
        replace_alert,
        text,
    )
    return text


def fix_cross_references(text: str) -> str:
    """Convert RST cross-reference artifacts to markdown anchor links."""
    # pandoc renders :ref:`patch-rollback` as `patch-rollback` (inline code)
    # Convert known refs to anchor links
    text = re.sub(
        r'`patch-rollback`',
        '[Patch rollback](#patch-rollback)',
        text,
    )
    return text


def fix_escaped_backticks(text: str) -> str:
    """Remove stray escaped backticks left by pandoc."""
    # \` at end/start of table cells
    text = re.sub(r'\\\`', '`', text)
    return text


def collapse_blank_lines(text: str) -> str:
    """Collapse runs of 3+ blank lines to 2."""
    return re.sub(r'\n{4,}', '\n\n\n', text)


def main():
    docs_dir = Path(__file__).parent
    rst_path = docs_dir / 'keaddns.rst'
    md_path = docs_dir / 'keaddns.md'

    if not rst_path.exists():
        print(f"Error: {rst_path} not found", file=sys.stderr)
        sys.exit(1)

    print(f"Converting {rst_path} -> {md_path}")

    text = pandoc_convert(rst_path)

    text = remove_contents_block(text)
    text = fix_menuselection(text)
    text = convert_admonition_divs(text)
    text = convert_html_tables(text)
    text = convert_tabs(text)
    text = fix_title_ref(text)
    text = fix_api_tables(text)
    text = fix_indented_code_blocks(text)
    text = fix_troubleshooting_headings(text)
    text = fix_escaped_backticks(text)
    text = fix_cross_references(text)
    text = convert_gfm_alerts(text)
    text = collapse_blank_lines(text)
    text = text.strip() + '\n'

    md_path.write_text(text)
    print(f"Done. Written {len(text)} bytes.")


if __name__ == '__main__':
    main()
