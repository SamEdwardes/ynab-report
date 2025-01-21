default:
  @just --list

render:
  uv run quarto render doc.qmd
  open doc.html
