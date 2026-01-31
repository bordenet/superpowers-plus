# Web Application Conventions

> **Priority**: HIGH - Apply to web apps/interfaces  
> **Source**: genesis Agents.md

## UI Workflow Principles

> **Never assume linear user behavior.**

Users will:
- Click buttons multiple times
- Navigate away mid-operation
- Use browser back/forward
- Refresh during operations
- Open multiple tabs

Design defensively for all scenarios.

## ⚠️ All Clickable Elements MUST Have Event Handlers

Every interactive element needs explicit handlers:

```javascript
// ✅ Correct - explicit handler
button.addEventListener('click', handleClick);

// ❌ Wrong - no handler attached
<button>Click me</button>  // Does nothing
```

## Clipboard Operations Pattern

Use throw-on-error pattern for clipboard:

```javascript
async function copyToClipboard(text) {
    try {
        await navigator.clipboard.writeText(text);
        showSuccess('Copied to clipboard');
    } catch (error) {
        showError('Failed to copy: ' + error.message);
        throw error;  // Re-throw for caller handling
    }
}
```

## Dark Mode Requirements

**MANDATORY**: All web interfaces must support dark mode.

```css
/* System preference detection */
@media (prefers-color-scheme: dark) {
    :root {
        --bg-color: #1a1a1a;
        --text-color: #e0e0e0;
    }
}

/* Manual toggle support */
[data-theme="dark"] {
    --bg-color: #1a1a1a;
    --text-color: #e0e0e0;
}
```

## Loading States

Always show loading states for async operations:

```javascript
async function fetchData() {
    setLoading(true);
    try {
        const data = await api.get('/data');
        setData(data);
    } finally {
        setLoading(false);
    }
}
```

## Error Display

- Show errors prominently
- Provide actionable guidance
- Allow retry where applicable
- Log details for debugging

