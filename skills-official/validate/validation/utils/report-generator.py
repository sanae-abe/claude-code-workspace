#!/usr/bin/env python3
"""
Validation Report Generator

Reads JSON validation reports and generates formatted text or JSON output.
Supports color-coded output and detailed error reporting.

Usage:
    report-generator.py <report.json>
    report-generator.py <report.json> --format=json
    report-generator.py <report.json> --format=text

Exit codes:
    0 - All gates passed
    1 - One or more gates failed
    2 - Invalid arguments or report parsing error

Security:
    - Uses sys.argv for arguments (no eval/exec)
    - Safe file operations with error handling
    - No dynamic code execution
"""

import sys
import json
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from enum import Enum


class ExitCode(Enum):
    """Exit codes for the report generator."""
    SUCCESS = 0
    VALIDATION_FAILED = 1
    SCRIPT_ERROR = 2


class Color:
    """ANSI color codes for terminal output."""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    BOLD = '\033[1m'
    NC = '\033[0m'  # No Color

    @classmethod
    def disable(cls):
        """Disable colors for non-interactive output."""
        cls.RED = ''
        cls.GREEN = ''
        cls.YELLOW = ''
        cls.BLUE = ''
        cls.CYAN = ''
        cls.BOLD = ''
        cls.NC = ''


@dataclass
class GateError:
    """Represents a single validation error."""
    file_path: str
    line: Optional[int]
    message: str
    suggestion: Optional[str] = None

    def format(self) -> str:
        """Format error with file:line reference."""
        location = f"{self.file_path}"
        if self.line is not None:
            location += f":{self.line}"

        output = f"  {Color.RED}❌{Color.NC} {location}\n"
        output += f"     {self.message}\n"

        if self.suggestion:
            output += f"     {Color.CYAN}💡 {self.suggestion}{Color.NC}\n"

        return output


@dataclass
class GateResult:
    """Represents validation result for a single gate."""
    name: str
    layer: str
    status: str  # "passed", "failed", "skipped"
    errors: List[GateError]
    warnings: List[str]
    auto_fixed: int = 0
    execution_time: Optional[float] = None

    def is_passed(self) -> bool:
        """Check if gate passed."""
        return self.status == "passed"

    def format_status(self) -> str:
        """Format status with emoji and color."""
        if self.status == "passed":
            return f"{Color.GREEN}✅ PASSED{Color.NC}"
        elif self.status == "failed":
            return f"{Color.RED}❌ FAILED{Color.NC}"
        else:  # skipped
            return f"{Color.YELLOW}⚠️  SKIPPED{Color.NC}"

    def format_detailed(self) -> str:
        """Format detailed gate result."""
        output = f"\n{Color.BOLD}{'─' * 60}{Color.NC}\n"
        output += f"{Color.BOLD}{self.name}{Color.NC} ({self.layer})\n"
        output += f"Status: {self.format_status()}\n"

        if self.execution_time is not None:
            output += f"Time: {self.execution_time:.2f}s\n"

        if self.auto_fixed > 0:
            output += f"{Color.YELLOW}Auto-fixed: {self.auto_fixed} issues{Color.NC}\n"

        if self.errors:
            output += f"\n{Color.RED}Errors ({len(self.errors)}):{Color.NC}\n"
            for error in self.errors:
                output += error.format()

        if self.warnings:
            output += f"\n{Color.YELLOW}Warnings ({len(self.warnings)}):{Color.NC}\n"
            for warning in self.warnings:
                output += f"  ⚠️  {warning}\n"

        return output


@dataclass
class ValidationReport:
    """Complete validation report."""
    gates: List[GateResult]
    total_gates: int
    passed_gates: int
    failed_gates: int
    auto_fixed_total: int
    timestamp: Optional[str] = None
    project_path: Optional[str] = None

    def is_success(self) -> bool:
        """Check if all gates passed."""
        return self.failed_gates == 0

    def format_summary(self) -> str:
        """Format summary section."""
        output = f"\n{Color.BOLD}{'═' * 60}{Color.NC}\n"
        output += f"{Color.BOLD}VALIDATION REPORT SUMMARY{Color.NC}\n"
        output += f"{Color.BOLD}{'═' * 60}{Color.NC}\n\n"

        if self.project_path:
            output += f"Project: {self.project_path}\n"
        if self.timestamp:
            output += f"Timestamp: {self.timestamp}\n"

        output += f"\nTotal Gates: {self.total_gates}\n"
        output += f"{Color.GREEN}Passed: {self.passed_gates}{Color.NC}\n"

        if self.failed_gates > 0:
            output += f"{Color.RED}Failed: {self.failed_gates}{Color.NC}\n"
        else:
            output += f"Failed: {self.failed_gates}\n"

        if self.auto_fixed_total > 0:
            output += f"{Color.YELLOW}Auto-fixed: {self.auto_fixed_total}{Color.NC}\n"

        output += f"\n{Color.BOLD}Overall Status: "
        if self.is_success():
            output += f"{Color.GREEN}✅ ALL GATES PASSED{Color.NC}{Color.BOLD}{Color.NC}\n"
        else:
            output += f"{Color.RED}❌ VALIDATION FAILED{Color.NC}{Color.BOLD}{Color.NC}\n"

        return output

    def format_text(self) -> str:
        """Format complete text report."""
        output = self.format_summary()

        # Per-gate results
        output += f"\n{Color.BOLD}{'═' * 60}{Color.NC}\n"
        output += f"{Color.BOLD}GATE RESULTS{Color.NC}\n"
        output += f"{Color.BOLD}{'═' * 60}{Color.NC}\n"

        for gate in self.gates:
            output += gate.format_detailed()

        # Final summary
        output += f"\n{Color.BOLD}{'═' * 60}{Color.NC}\n"

        if self.is_success():
            output += f"{Color.GREEN}{Color.BOLD}✅ VALIDATION SUCCESSFUL{Color.NC}\n"
        else:
            output += f"{Color.RED}{Color.BOLD}❌ VALIDATION FAILED{Color.NC}\n"
            output += f"\n{Color.YELLOW}Suggestions for fixes:{Color.NC}\n"

            failed_count = 0
            for gate in self.gates:
                if not gate.is_passed():
                    failed_count += 1
                    output += f"\n{failed_count}. {gate.name}:\n"

                    if gate.errors:
                        for error in gate.errors:
                            if error.suggestion:
                                output += f"   • {error.suggestion}\n"
                    else:
                        output += f"   • Review {gate.layer} requirements\n"

        output += f"{Color.BOLD}{'═' * 60}{Color.NC}\n"

        return output

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON output."""
        return {
            "summary": {
                "total_gates": self.total_gates,
                "passed": self.passed_gates,
                "failed": self.failed_gates,
                "auto_fixed": self.auto_fixed_total,
                "success": self.is_success(),
                "timestamp": self.timestamp,
                "project_path": self.project_path
            },
            "gates": [
                {
                    "name": gate.name,
                    "layer": gate.layer,
                    "status": gate.status,
                    "errors": [
                        {
                            "file": err.file_path,
                            "line": err.line,
                            "message": err.message,
                            "suggestion": err.suggestion
                        }
                        for err in gate.errors
                    ],
                    "warnings": gate.warnings,
                    "auto_fixed": gate.auto_fixed,
                    "execution_time": gate.execution_time
                }
                for gate in self.gates
            ]
        }


class ReportParser:
    """Parse JSON validation reports."""

    @staticmethod
    def parse_error(error_data: Dict[str, Any]) -> GateError:
        """Parse a single error from JSON."""
        return GateError(
            file_path=error_data.get("file", "unknown"),
            line=error_data.get("line"),
            message=error_data.get("message", "No message"),
            suggestion=error_data.get("suggestion")
        )

    @staticmethod
    def parse_gate(gate_data: Dict[str, Any]) -> GateResult:
        """Parse a single gate result from JSON."""
        errors = [
            ReportParser.parse_error(err)
            for err in gate_data.get("errors", [])
        ]

        return GateResult(
            name=gate_data.get("name", "Unknown Gate"),
            layer=gate_data.get("layer", "unknown"),
            status=gate_data.get("status", "unknown"),
            errors=errors,
            warnings=gate_data.get("warnings", []),
            auto_fixed=gate_data.get("auto_fixed", 0),
            execution_time=gate_data.get("execution_time")
        )

    @staticmethod
    def parse(json_data: Dict[str, Any]) -> ValidationReport:
        """Parse complete validation report from JSON."""
        gates = [
            ReportParser.parse_gate(gate)
            for gate in json_data.get("gates", [])
        ]

        summary = json_data.get("summary", {})

        return ValidationReport(
            gates=gates,
            total_gates=summary.get("total_gates", len(gates)),
            passed_gates=summary.get("passed", 0),
            failed_gates=summary.get("failed", 0),
            auto_fixed_total=summary.get("auto_fixed", 0),
            timestamp=summary.get("timestamp"),
            project_path=summary.get("project_path")
        )


def parse_args() -> tuple[str, str]:
    """
    Parse command line arguments.

    Returns:
        tuple: (report_path, output_format)

    Raises:
        ValueError: If arguments are invalid
    """
    if len(sys.argv) < 2:
        raise ValueError("Missing required argument: report.json")

    report_path = sys.argv[1]
    output_format = "text"  # default

    # Parse optional format flag
    for arg in sys.argv[2:]:
        if arg.startswith("--format="):
            output_format = arg.split("=", 1)[1]
            if output_format not in ("text", "json"):
                raise ValueError(f"Invalid format: {output_format}. Use 'text' or 'json'")

    return report_path, output_format


def read_report_file(file_path: str) -> Dict[str, Any]:
    """
    Read and parse JSON report file.

    Args:
        file_path: Path to JSON report file

    Returns:
        Parsed JSON data

    Raises:
        FileNotFoundError: If file doesn't exist
        json.JSONDecodeError: If JSON is invalid
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"Report file not found: {file_path}")
    except json.JSONDecodeError as e:
        raise json.JSONDecodeError(
            f"Invalid JSON in report file: {e.msg}",
            e.doc,
            e.pos
        )


def main() -> int:
    """
    Main entry point.

    Returns:
        Exit code
    """
    try:
        # Parse arguments
        report_path, output_format = parse_args()

        # Disable colors if not outputting to terminal or if JSON format
        if not sys.stdout.isatty() or output_format == "json":
            Color.disable()

        # Read and parse report
        json_data = read_report_file(report_path)
        report = ReportParser.parse(json_data)

        # Generate output
        if output_format == "json":
            print(json.dumps(report.to_dict(), indent=2))
        else:  # text
            print(report.format_text())

        # Exit code based on validation result
        if report.is_success():
            return ExitCode.SUCCESS.value
        else:
            return ExitCode.VALIDATION_FAILED.value

    except (ValueError, FileNotFoundError, json.JSONDecodeError) as e:
        print(f"{Color.RED}ERROR: {e}{Color.NC}", file=sys.stderr)
        return ExitCode.SCRIPT_ERROR.value

    except Exception as e:
        print(f"{Color.RED}ERROR: Unexpected error: {e}{Color.NC}", file=sys.stderr)
        return ExitCode.SCRIPT_ERROR.value


if __name__ == "__main__":
    sys.exit(main())
