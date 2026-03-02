# Facets Cloud — Claude Code Plugins

Claude Code skills for the [Facets Cloud](https://facets.cloud) platform. Two plugins available — choose based on your workflow.

## Plugins

| Plugin | Approach | Best for |
|--------|----------|----------|
| **[facets-plugin-v2](facets-plugin-v2/README.md)** | Natural language — describe what you want | Anyone, no CLI knowledge needed |
| **[facets-plugin](facets-plugin/README.md)** | CLI-oriented — direct Raptor commands | Platform engineers who want fine-grained control |

### Quick Install

```bash
# Add the marketplace (one-time)
/plugin marketplace add Facets-cloud/claude-plugin

# Install v2 (recommended) — natural language interface
/plugin install facets-plugin-v2@facets-marketplace

# OR install v1 — CLI-oriented interface
/plugin install facets-plugin@facets-marketplace
```

Both plugins can be installed side-by-side.

## License

MIT
