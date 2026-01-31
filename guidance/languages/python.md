# Python Coding Conventions

> **Priority**: HIGH - Apply to all Python projects  
> **Source**: pr-faq-validator, bloginator Agents.md

## Code Quality Requirements

- **Line length**: 100 characters maximum
- **Linting**: pylint score ≥9.5
- **Type checking**: mypy (strict mode preferred)
- **Coverage**: ≥50% minimum, 70%+ target

## Style Guide

```python
# Type annotations on all public functions
def process_file(path: str, options: dict[str, Any] | None = None) -> Result:
    """Process a file with optional configuration.
    
    Args:
        path: Path to the file to process
        options: Optional configuration dictionary
        
    Returns:
        Result object with processing outcome
        
    Raises:
        FileNotFoundError: If path doesn't exist
        ValueError: If file format is invalid
    """
    ...
```

## Import Organization

```python
# Standard library
import os
import sys
from pathlib import Path

# Third-party
import requests
from pydantic import BaseModel

# Local
from .utils import helper
from ..core import process
```

## Testing Patterns

```python
import pytest

class TestProcessor:
    """Tests for Processor class."""
    
    def test_process_valid_input(self, tmp_path):
        """Should process valid input successfully."""
        file_path = tmp_path / "test.txt"
        file_path.write_text("content")
        
        result = Processor().process(file_path)
        
        assert result.success
        assert result.output == "expected"
    
    def test_process_missing_file(self):
        """Should raise FileNotFoundError for missing file."""
        with pytest.raises(FileNotFoundError):
            Processor().process("/nonexistent")
```

## Commands

```bash
# Lint
pylint src/

# Type check
mypy src/

# Test with coverage
pytest --cov=src --cov-report=term-missing

# Security scan
pip-audit -r requirements.txt
```

