"""节气工具 - 根据日期判断当前节气"""

from datetime import datetime, date


# 二十四节气数据（近似日期，每年可能有1-2天偏差）
# 格式: (月份, 日, 节气名)
SOLAR_TERMS = [
    (1, 6, "小寒"), (1, 20, "大寒"),
    (2, 4, "立春"), (2, 19, "雨水"),
    (3, 6, "惊蛰"), (3, 21, "春分"),
    (4, 5, "清明"), (4, 20, "谷雨"),
    (5, 6, "立夏"), (5, 21, "小满"),
    (6, 6, "芒种"), (6, 21, "夏至"),
    (7, 7, "小暑"), (7, 23, "大暑"),
    (8, 7, "立秋"), (8, 23, "处暑"),
    (9, 8, "白露"), (9, 23, "秋分"),
    (10, 8, "寒露"), (10, 23, "霜降"),
    (11, 7, "立冬"), (11, 22, "小雪"),
    (12, 7, "大雪"), (12, 22, "冬至"),
]

# 节气对应的季节
TERM_SEASON = {
    "立春": "春", "雨水": "春", "惊蛰": "春", "春分": "春", "清明": "春", "谷雨": "春",
    "立夏": "夏", "小满": "夏", "芒种": "夏", "夏至": "夏", "小暑": "夏", "大暑": "夏",
    "立秋": "秋", "处暑": "秋", "白露": "秋", "秋分": "秋", "寒露": "秋", "霜降": "秋",
    "立冬": "冬", "小雪": "冬", "大雪": "冬", "冬至": "冬", "小寒": "冬", "大寒": "冬",
}

# 节气养生要点
TERM_WELLNESS = {
    "立春": "养肝护阳，宜食韭菜、香菜、花生，少酸增甘",
    "雨水": "健脾祛湿，宜食山药、红枣、小米粥",
    "惊蛰": "疏肝理气，宜食菠菜、芹菜、梨",
    "春分": "调和阴阳，饮食均衡，宜食荠菜、香椿",
    "清明": "养肝明目，宜食枸杞、菊花茶、桑葚",
    "谷雨": "健脾祛湿，宜食薏仁、红豆、鲫鱼",
    "立夏": "养心安神，宜食莲子、苦瓜、绿豆",
    "小满": "清热利湿，宜食冬瓜、薏仁、黄瓜",
    "芒种": "清热解暑，宜食绿豆汤、酸梅汤、西瓜",
    "夏至": "养心降火，宜食莲子心茶、绿豆、百合",
    "小暑": "清暑益气，宜食莲藕、丝瓜、荷叶粥",
    "大暑": "清热祛湿，宜食绿豆、薏仁、西瓜",
    "立秋": "润燥养肺，宜食银耳、梨、蜂蜜",
    "处暑": "滋阴润燥，宜食百合、莲子、山药",
    "白露": "养肺润燥，宜食梨、银耳、芝麻",
    "秋分": "滋阴润肺，宜食百合、蜂蜜、雪梨",
    "寒露": "润肺生津，宜食柿子、石榴、芝麻",
    "霜降": "温补脾胃，宜食栗子、山药、红枣",
    "立冬": "温补养肾，宜食羊肉、核桃、黑豆",
    "小雪": "温肾助阳，宜食羊肉、桂圆、红枣",
    "大雪": "补肾温阳，宜食羊肉、黑芝麻、核桃",
    "冬至": "温补藏精，宜食羊肉、饺子、汤圆",
    "小寒": "温补御寒，宜食羊肉、姜汤、红枣",
    "大寒": "温补藏精，宜食羊肉、核桃、栗子",
}


def get_current_solar_term(target_date: date | None = None) -> dict:
    """获取当前节气信息

    Args:
        target_date: 目标日期，默认为今天

    Returns:
        dict: 包含当前节气名、季节、养生要点、下一节气等信息
    """
    if target_date is None:
        target_date = date.today()

    current_term = None
    next_term = None

    for i, (month, day, name) in enumerate(SOLAR_TERMS):
        term_date = date(target_date.year, month, day)
        if term_date <= target_date:
            current_term = name
            # 下一节气
            if i + 1 < len(SOLAR_TERMS):
                next_month, next_day, next_name = SOLAR_TERMS[i + 1]
                next_date = date(target_date.year, next_month, next_day)
                next_term = next_name
            else:
                # 跨年：下一节气是第一个
                next_month, next_day, next_name = SOLAR_TERMS[0]
                next_date = date(target_date.year + 1, next_month, next_day)
                next_term = next_name
        else:
            if current_term is None:
                # 年初，当前节气是上一年的最后一个
                current_term = SOLAR_TERMS[-1][2]
                next_term = name
            break

    if current_term is None:
        current_term = "大寒"
        next_term = "立春"

    season = TERM_SEASON.get(current_term, "未知")
    wellness = TERM_WELLNESS.get(current_term, "")

    return {
        "name": current_term,
        "season": season,
        "wellness": wellness,
        "next_term": next_term,
    }


def get_upcoming_solar_term(days_ahead: int = 3, target_date: date | None = None) -> dict | None:
    """获取即将到来的节气信息（指定天数内）

    Args:
        days_ahead: 提前天数，默认3天
        target_date: 目标日期，默认为今天

    Returns:
        dict: 包含节气名、日期、季节、养生要点，如果近期无节气则返回 None
    """
    if target_date is None:
        target_date = date.today()

    for i, (month, day, name) in enumerate(SOLAR_TERMS):
        term_date = date(target_date.year, month, day)
        delta = (term_date - target_date).days
        if 0 < delta <= days_ahead:
            season = TERM_SEASON.get(name, "未知")
            wellness = TERM_WELLNESS.get(name, "")
            return {
                "name": name,
                "date": term_date.isoformat(),
                "days_ahead": delta,
                "season": season,
                "wellness": wellness,
            }

    # 检查跨年情况：年初时，下一年的第一个节气可能在3天内
    next_year_first = SOLAR_TERMS[0]
    next_year_date = date(target_date.year + 1, next_year_first[0], next_year_first[1])
    delta = (next_year_date - target_date).days
    if 0 < delta <= days_ahead:
        name = next_year_first[2]
        season = TERM_SEASON.get(name, "未知")
        wellness = TERM_WELLNESS.get(name, "")
        return {
            "name": name,
            "date": next_year_date.isoformat(),
            "days_ahead": delta,
            "season": season,
            "wellness": wellness,
        }

    return None
