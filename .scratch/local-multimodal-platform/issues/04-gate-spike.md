# 质量闸门 Spike：段落↔图片匹配的 nDCG@10

Type: prototype
Blocked by: 01

## Question

用 200 段落 × 300 图人工标注，测「段落 → 图片」排序的 nDCG@10，判定直连向量检索是否可用；若低于 ~0.55，改走 caption 中介 + LLM 相关性判定。

产出：可复跑的评测脚本 + 标注集 + 两套方案的对比数。这是全项目的 kill-criterion。
