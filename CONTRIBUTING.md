# Contributing to comfYa

Thank you for your interest in contributing to comfYa!

## Code of Conduct

Be respectful and constructive.

## How to Contribute

### Bug Reports

Use the [Bug Report template](/.github/ISSUE_TEMPLATE/bug_report.yml) with:
- OS and GPU info
- Driver version
- Steps to reproduce
- Error logs

### Feature Requests

Use the [Feature Request template](/.github/ISSUE_TEMPLATE/feature_request.yml).

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes following our style guide
4. Run tests: `Invoke-Pester -Path ./tests`
5. Commit with clear message: `git commit -m "feat: add my feature"`
6. Push and open PR

## Code Style

### PowerShell
- Use approved verbs (`Get-`, `Set-`, `New-`, etc.)
- Include comment-based help for functions
- Use `$ErrorActionPreference = 'Stop'`
- Prefer splatting for long parameter lists

### Python
- Follow PEP 8
- Use type hints
- Docstrings for public functions

## Testing

```powershell
# Install Pester
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run tests
Invoke-Pester -Path ./tests -Output Detailed
```

## Commit Messages

Format: `<type>: <description>`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `test`: Tests
- `ci`: CI/CD changes

## Questions?

Open a [Discussion](https://github.com/FeelTheFonk/comfYa/discussions) or issue.
