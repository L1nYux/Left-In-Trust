extends RefCounted

## The player's life stage is independent of AI companions and combat resources.
const DEFAULT := "student"
const IDS := ["student", "graduate", "employee", "researcher", "expert", "wealthy"]
const THEMES := {
	"student": {"name": "大学生", "paper": Color("ceccbf"), "accent": Color("96907c")},
	"graduate": {"name": "研究生", "paper": Color("cac9c0"), "accent": Color("898d83")},
	"employee": {"name": "公司员工", "paper": Color("c5c9c3"), "accent": Color("7c8d89")},
	"researcher": {"name": "研究员", "paper": Color("c4c9c8"), "accent": Color("7b8d96")},
	"expert": {"name": "行业大佬", "paper": Color("c9c7c0"), "accent": Color("91877d")},
	"wealthy": {"name": "富翁", "paper": Color("cecbc2"), "accent": Color("958d78")}
}


static func normalize(stage_id: String) -> String:
	return stage_id if THEMES.has(stage_id) else DEFAULT


static func display_name(stage_id: String) -> String:
	return str(THEMES[normalize(stage_id)]["name"])
