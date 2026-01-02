#!/usr/bin/env python3
"""
comfYa Validator Tests
T2: Unit tests for validate.py logic
"""
import sys
import json
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest


class TestComfyConfig:
    """Tests for ComfyConfig class."""
    
    def test_load_bridge_missing_file(self, tmp_path):
        """Should return empty dict if config.json missing."""
        from validate import ComfyConfig
        result = ComfyConfig.load_bridge(tmp_path)
        assert result == {}
    
    def test_load_bridge_valid_json(self, tmp_path):
        """Should load valid JSON config."""
        from validate import ComfyConfig
        config = {"Version": "0.2.7", "Python": {"Version": "3.12"}}
        (tmp_path / "config.json").write_text(json.dumps(config))
        result = ComfyConfig.load_bridge(tmp_path)
        assert result["Version"] == "0.2.7"
    
    def test_load_bridge_invalid_json(self, tmp_path):
        """Should return empty dict on invalid JSON."""
        from validate import ComfyConfig
        (tmp_path / "config.json").write_text("{invalid json")
        result = ComfyConfig.load_bridge(tmp_path)
        assert result == {}
    
    def test_get_min_cc_default(self):
        """Should return 7.5 as default min CC."""
        from validate import ComfyConfig
        result = ComfyConfig.get_min_cc({})
        assert result == 7.5
    
    def test_get_min_cc_from_config(self):
        """Should extract min CC from config."""
        from validate import ComfyConfig
        config = {"Gpu": {"MinComputeCapability": 8.0}}
        result = ComfyConfig.get_min_cc(config)
        assert result == 8.0
    
    def test_get_py_version_default(self):
        """Should return 3.12 as default."""
        from validate import ComfyConfig
        result = ComfyConfig.get_py_version({})
        assert result == "3.12"


class TestValidationFunctions:
    """Tests for validation functions."""
    
    def test_test_config_bridge_missing(self, tmp_path):
        """Should fail if config.json missing."""
        from validate import test_config_bridge
        passed, details = test_config_bridge(tmp_path)
        assert passed is False
        assert "not found" in details
    
    def test_test_config_bridge_valid(self, tmp_path):
        """Should pass for valid config.json."""
        from validate import test_config_bridge
        config = {"Version": "0.2.7", "Python": {"Version": "3.12"}}
        (tmp_path / "config.json").write_text(json.dumps(config))
        passed, details = test_config_bridge(tmp_path)
        assert passed is True
        assert "0.2.7" in details
    
    def test_test_python_version_match(self):
        """Should pass when Python version matches."""
        from validate import test_python_version
        config = {"Python": {"Version": f"{sys.version_info.major}.{sys.version_info.minor}"}}
        passed, details = test_python_version(config)
        assert passed is True
    
    def test_test_directories_existing(self, tmp_path):
        """Should report existing directories."""
        from validate import test_directories
        # Create expected directories
        (tmp_path / "models").mkdir()
        (tmp_path / "output").mkdir()
        (tmp_path / "logs").mkdir()
        (tmp_path / "ComfyUI").mkdir()
        
        passed, details = test_directories(tmp_path, {})
        assert passed is True
        assert "4 directories OK" in details


class TestCorePackages:
    """Tests for package verification."""
    
    def test_test_core_packages_with_config(self):
        """Should read package list from config."""
        from validate import test_core_packages
        config = {"Packages": {"Core": ["sys", "os"]}}  # Built-in modules
        passed, details = test_core_packages(config)
        # sys and os should always be found
        assert "2 core packages OK" in details or passed is True


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
