#!/usr/bin/env sh
# Gera um CONTEXT.md único com toda a doc compartilhada, na ordem de leitura.
# Use o arquivo gerado para subir em ferramentas que ingerem por upload (NotebookLM, Gemini Gems).
set -e
cd "$(dirname "$0")/.."
OUT="CONTEXT.md"
: > "$OUT"
for f in manifest.md _meta/conventions.md _meta/glossary.md \
         product.md requirements.md roadmap.md \
         design/AYD-*.md product_decisions/PDR-*.md architecture_decisions/ADR-*.md; do
  [ -f "$f" ] || continue
  printf '\n\n<!-- ===== %s ===== -->\n\n' "$f" >> "$OUT"
  cat "$f" >> "$OUT"
done
echo "✓ gerado $OUT ($(wc -l < "$OUT") linhas)"
