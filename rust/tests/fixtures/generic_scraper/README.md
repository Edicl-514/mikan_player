# generic_scraper fixtures

Minimal, deterministic HTML pages used by the RT-2 offline tests for the
generic scraper search → channel → episode → play pipeline.

- `search_indexed.html` — an "indexed" subject list with one matching title
  (`测试动画`) and one unrelated title. Links are relative so the tests can
  assert that the loopback origin (including its ephemeral port) is preserved.
- `detail_index_grouped.html` — an "index-grouped" detail page with two
  channels (`线路A` / `线路B`) and per-channel episode lists using relative
  hrefs.
- `detail_no_channel.html` — a "no-channel" detail page with a flat episode
  list using relative hrefs.
- `detail_empty.html` — a detail page with no channels and no episodes; used to
  exercise the "fall back to the next subject candidate" branch.

All hrefs are site-relative on purpose: the fixtures are served from a random
loopback port, so relative-URL absolutization is part of what the tests verify.
