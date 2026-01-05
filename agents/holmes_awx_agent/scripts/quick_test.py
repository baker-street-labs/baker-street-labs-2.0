#!/usr/bin/env python3
"""
Quick test script to verify Holmes AWX Agent components
"""

import sys
import os

# Try to find repo root from environment or default location
repo_root = os.environ.get('HOLMES_AGENT_ROOT', os.path.expanduser('~/agentic-pipeline/baker-street-labs'))
if not os.path.exists(repo_root):
    # Fallback: try to find it relative to script location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, '..', '..', '..'))
    
sys.path.insert(0, repo_root)
print(f"Repository root: {repo_root}")
print(f"Checking if services directory exists: {os.path.exists(os.path.join(repo_root, 'services'))}")

def test_imports():
    """Test that all modules can be imported."""
    print("Testing imports...")
    try:
        from services.holmes_awx_agent import config
        print("  ✓ config")
        
        from services.holmes_awx_agent import models
        print("  ✓ models")
        
        from services.holmes_awx_agent import job_manager
        print("  ✓ job_manager")
        
        from services.holmes_awx_agent import awx_adapter
        print("  ✓ awx_adapter")
        
        from services.holmes_awx_agent import llm_provider
        print("  ✓ llm_provider")
        
        from services.holmes_awx_agent import tools
        print("  ✓ tools")
        
        from services.holmes_awx_agent import llm_orchestrator
        print("  ✓ llm_orchestrator")
        
        from services.holmes_awx_agent import graph
        print("  ✓ graph")
        
        from services.holmes_awx_agent import webhook_handler
        print("  ✓ webhook_handler")
        
        from services.holmes_awx_agent import main
        print("  ✓ main")
        
        print("\n✅ All imports successful!")
        return True
    except Exception as e:
        print(f"\n❌ Import failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_config():
    """Test configuration loading."""
    print("\nTesting configuration...")
    try:
        from services.holmes_awx_agent.config import get_settings
        settings = get_settings()
        print(f"  ✓ AWX API URL: {settings.awx_api_url}")
        print(f"  ✓ LLM Provider: {settings.llm_provider}")
        print(f"  ✓ Username set: {'Yes' if settings.awx_username else 'No'}")
        print("\n✅ Configuration loaded!")
        return True
    except Exception as e:
        print(f"\n❌ Configuration failed: {e}")
        return False

def test_models():
    """Test model creation."""
    print("\nTesting models...")
    try:
        from services.holmes_awx_agent.models import (
            JobTemplateRequest,
            OrchestrationRequest,
            AWXJob,
            OrchestrationJob,
        )
        
        # Test JobTemplateRequest
        req = JobTemplateRequest(job_template_name="test")
        print(f"  ✓ JobTemplateRequest: {req.job_template_name}")
        
        # Test OrchestrationRequest
        orch = OrchestrationRequest(request="test request")
        print(f"  ✓ OrchestrationRequest: {orch.request}")
        
        # Test AWXJob
        job = AWXJob(request=req)
        print(f"  ✓ AWXJob created: {job.job_id}")
        
        print("\n✅ Models work!")
        return True
    except Exception as e:
        print(f"\n❌ Models failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all tests."""
    print("=" * 60)
    print("Holmes AWX Agent - Quick Test")
    print("=" * 60)
    print()
    
    results = []
    results.append(("Imports", test_imports()))
    results.append(("Configuration", test_config()))
    results.append(("Models", test_models()))
    
    print("\n" + "=" * 60)
    print("Test Results:")
    print("=" * 60)
    for name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {name}: {status}")
    
    all_passed = all(r[1] for r in results)
    print()
    if all_passed:
        print("🎉 All tests passed!")
        return 0
    else:
        print("⚠️  Some tests failed")
        return 1

if __name__ == "__main__":
    sys.exit(main())

