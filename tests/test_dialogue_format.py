"""Validation tests for dialogue data JSON files."""

import json
import os
import glob

DATA_ROOT = os.path.join(os.path.dirname(__file__), "..", "data")
DIALOGUE_DIR = os.path.join(DATA_ROOT, "dialogue")

def test_dialogue_files_valid_json():
    """Ensure all dialogue files are valid JSON and follow the basic schema."""
    if not os.path.exists(DIALOGUE_DIR):
        return  # Nothing to test yet if dir missing

    dialogue_files = glob.glob(os.path.join(DIALOGUE_DIR, "*.json"))
    
    assert len(dialogue_files) > 0, "No dialogue files found in data/dialogue/"

    for filepath in dialogue_files:
        with open(filepath, encoding="utf-8") as f:
            data = json.load(f)

        assert "dialogue_tree_id" in data, f"Missing dialogue_tree_id in {filepath}"
        assert "character_id" in data, f"Missing character_id in {filepath}"
        assert "nodes" in data, f"Missing nodes dict in {filepath}"
        
        nodes = data["nodes"]
        assert "root" in nodes, f"Missing 'root' node in {filepath}"

        for node_id, node_data in nodes.items():
            assert "text" in node_data, f"Node {node_id} missing text in {filepath}"
            assert "choices" in node_data, f"Node {node_id} missing choices in {filepath}"
            
            for choice in node_data["choices"]:
                assert "text" in choice, f"Choice missing text in {node_id} ({filepath})"
                
                # Check outcome format if conditions exist (leaf nodes may have no choices/next node)
                if "next_node_id" in choice:
                    assert choice["next_node_id"] in nodes or choice["next_node_id"] == "end_conversation", \
                        f"Choice points to missing node {choice['next_node_id']} in {filepath}"
                    
                    if "outcome" in choice:
                        outcome = choice["outcome"]
                        assert "faction_changes" in outcome, f"Missing faction_changes in outcome"
                        assert "resource_changes" in outcome, f"Missing resource_changes in outcome"
                        assert "story_flags_set" in outcome, f"Missing story_flags_set in outcome"
                        assert "story_flags_cleared" in outcome, f"Missing story_flags_cleared in outcome"
