# Test Cleanup Guide

> **Status**: This document is a stub. The full test cleanup guide is being developed.

## Summary

Retrace follows a strict testing philosophy: **test with real input data, not fake structures**. Tests that create data and then validate what they created ("cop and thief" tests) provide zero confidence about real system behavior.

For the current testing philosophy and requirements, see:

- [CONTRIBUTING.md](CONTRIBUTING.md) -- Testing Requirements section (comprehensive)
- [AGENTS.md](AGENTS.md) -- "CRITICAL: Test with REAL Input Data" section
- Module-level `AGENTS.md` files -- Module-specific test strategies

## Planned Content

This guide will document:

- Inventory of tests that need cleanup (circular/fake-data tests)
- Migration path from fake-data tests to real-API tests
- Test asset requirements (`test_assets/` directory structure)
- Coverage targets per module
