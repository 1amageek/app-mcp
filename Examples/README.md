# AppMCP Examples

This directory contains examples and testing utilities for AppMCP.

## Testing Policy

**CRITICAL**: Only use the unified test client `test_client.py` for all Python testing. Do not create additional test files.

## Usage

### Unified Test Client

The `test_client.py` provides comprehensive testing for all AppMCP functionality:

```bash
# Run basic functionality tests
python3 Examples/test_client.py basic

# Run comprehensive test suite
python3 Examples/test_client.py comprehensive

# Run demonstration of text recognition improvements
python3 Examples/test_client.py demo
```

### Test Types

- **basic**: Core functionality tests (application discovery, Chrome UI, text recognition, error handling)
- **comprehensive**: Full test suite including Weather app, Finder automation, and all basic tests
- **demo**: Demonstration of block-level text recognition improvements

### Adding New Tests

To add new test scenarios:

1. Add a new test method to the `AppMCPTestClient` class in `test_client.py`
2. Follow the naming convention: `test_[functionality_name](self)`
3. Add the test to the appropriate suite (`run_basic_tests` or `run_comprehensive_tests`)
4. Include proper error handling and result reporting

### Architecture

The test client is designed as a unified interface to prevent Examples directory clutter:

- **Single File Policy**: All testing functionality in one file
- **Modular Design**: Test methods organized by functionality
- **Comprehensive Coverage**: Tests all AppMCP tools and scenarios
- **Clear Reporting**: Structured output with pass/fail indicators

## Features Tested

- Application discovery and listing
- UI element extraction and analysis
- Block-level text recognition with Vision Framework
- Chrome browser automation
- Weather app automation
- Finder automation
- Error handling and edge cases
- MCP protocol communication

## Requirements

- AppMCP server running (`swift run appmcpd`)
- Python 3.7+
- Target applications (Chrome, Weather, Finder) for comprehensive testing