---
title: 內蒙古總覽
type: travel-dashboard
tags:
  - travel
---

# 內蒙古總覽

## 地圖

```mapview
{"name":"內蒙古之旅","mapZoom":6,"centerLat":48.3,"centerLng":119.9,"query":"","autoFit":true}
```

## 行程表

```dataview
TABLE WITHOUT ID file.link as "項目", date as "日期", start as "開始", end as "結束", place as "地點"
FROM "notes/內蒙古之旅"
WHERE itinerary
SORT date ASC, start ASC
```

### 今日行程

```dataview
TABLE WITHOUT ID file.link as "項目", start as "開始"
FROM "notes/內蒙古之旅"
WHERE itinerary AND dateformat(date, "yyyy-MM-dd") = dateformat(date(today), "yyyy-MM-dd")
SORT start ASC
```

## 待辦

```dataview
TASK FROM "notes/內蒙古之旅"
WHERE !completed
```
