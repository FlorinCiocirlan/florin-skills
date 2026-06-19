# florin-skills

Claude Code marketplace by [Florin Ciocirlan](https://github.com/FlorinCiocirlan).

## Plugins

### writing-plans-html

Write a rigorous, task-by-task implementation plan, then render it as a **self-contained HTML page** and serve it on a local URL. The page has a sticky outline/TOC, copy buttons, progress-tracking checkboxes (state persists in the browser), and **atom-one-dark syntax highlighting** on every code block. Renders fully offline — `marked.js` + `highlight.js` + CSS are inlined, zero CDN.

## Install

```
/plugin marketplace add FlorinCiocirlan/florin-skills
/plugin install writing-plans-html@florin-skills
```

Then ask for a plan "as HTML" / "as a web page" / "served on localhost".
