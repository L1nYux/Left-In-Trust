# 当前构建与验算入口

当前编辑源是根目录及 docs 中的当前 Markdown、`docs/首批内容.json` 和 `角色设定/性格/*.md`。`_build/src` 仅为角色 Markdown 镜像。

1. 修改规则或数值后，运行 `validate_gameplay_v05.cjs`，结果写到 `docs/综合验算结果.json`；同步验证报告。
2. 修改角色或总览/玩法 Markdown 后，运行 `review/build_word.py` 生成 Word；可附文件名主体仅更新一份。同步角色镜像。
3. Windows 当前环境使用 `review/export_word.ps1` 后台只读导出 PDF，再运行 `review/render_word.py`；只有在本机 Word 可用时适用。每次 Word 改动都要重新导出、渲染并看改动页面。
4. 运行 `review/audit_sources.py` 检查当前链接、文本同步、原始备份与原图。页面仍须人工查看。
5. 修改剧情文本后：草稿在 `_build/story_drafts/`，运行 `assemble_story.cjs` 拼装 `docs/Demo剧情脚本.md`，再运行 `validate_story.cjs`（格式 + 覆盖）。重复游玩闲聊草稿在 `_build/chat_drafts/`，运行 `assemble_chat.cjs` 拼装 `docs/剧情/日常闲聊台词.md`、`validate_chat.cjs` 校验并 `--json` 导出运行时文件；Claude 草稿文件名必须是 `Claude_pool.md`（`CLAUDE.md` 会被工具当作说明文件加载）。

`review/extract_sources.py`、`review/revise_characters.py`、`review/build_content.py`、`review/finalize_sources.py` 是本轮一次性盘点、迁移工具，不能用来覆盖后续手工编辑。`source_inventory.json` 是整理前清单，不能重建成当前文件清单。卡牌表由 `review/build_card_catalog.py` 从当前 JSON 导出。

`历史验证器/validate_gameplay_v02/v03/v04.cjs` 和 `docs/历史/旧版本` 中的对应 JSON 仅复现历史设计，不代表现版通过。`add_muse.py`、`muse/polish_documents.py`、`character_sync/sync_characters.py` 等是历史迁移工具，不进入当前流程。旧 Word 输出、旧预览和 `review/current` 为中间产物，文件名较新不等于规则较新。

规则模型不是游戏引擎；不要将其示例中的直接状态赋值用于正式游戏接口。
