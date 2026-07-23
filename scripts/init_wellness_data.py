# -*- coding: utf-8 -*-
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.models.database import SessionLocal
from shared.models.wellness_models import WellnessKnowledge
import json

# 数据来源依据：中华人民共和国《中医体质分类与判定》标准(ZYYXH/T157-2009)
# 《黄帝内经·四气调神大论》四季养生原则
# 中国居民膳食指南(2022)
# 各节气传统饮食习俗与中医食养学

data = [
    # ============================================================
    # 一、24 节气饮食指南（共 24 条）
    # ============================================================

    # ---------- 春季（6 节气）养生原则：养肝护肝，升发阳气 ----------
    {
        "category": "节气",
        "sub_category": "立春",
        "title": "立春节气饮食指南",
        "content": "立春为二十四节气之首，《黄帝内经》云「春三月，此谓发陈」，阳气初生，万物复苏。饮食宜辛甘发散之品以助阳气升发，少食酸收之味以免碍肝气疏泄。",
        "recommended_foods": json.dumps({"ingredients": ["韭菜", "豆芽", "春笋", "红枣", "枸杞", "荠菜"], "recipes": [{"name": "韭菜炒鸡蛋", "description": "韭菜切段，鸡蛋打散，先炒蛋再下韭菜快炒，加盐调味", "benefits": "温阳散寒，助阳气升发"}]}),
        "avoid_foods": json.dumps({"items": ["酸味食物过食", "寒凉生冷食物", "油腻厚味"]}),
        "applicable_constitutions": json.dumps(["平和质", "气虚质", "阳虚质"]),
        "season": "春季",
        "solar_term": "立春"
    },
    {
        "category": "节气",
        "sub_category": "雨水",
        "title": "雨水节气饮食指南",
        "content": "雨水时节降水增多，湿气渐重，易困脾胃。《遵生八笺》载此节气当「调养脾胃」。饮食宜健脾祛湿，少食生冷甜腻以防助湿。",
        "recommended_foods": json.dumps({"ingredients": ["山药", "薏仁", "茯苓", "白扁豆", "小米", "鲫鱼"], "recipes": [{"name": "山药薏仁粥", "description": "山药去皮切块，与薏仁、粳米同煮至软烂", "benefits": "健脾益气，利水渗湿"}]}),
        "avoid_foods": json.dumps({"items": ["生冷瓜果", "甜腻糕点", "油炸食物"]}),
        "applicable_constitutions": json.dumps(["痰湿质", "气虚质", "平和质"]),
        "season": "春季",
        "solar_term": "雨水"
    },
    {
        "category": "节气",
        "sub_category": "惊蛰",
        "title": "惊蛰节气饮食指南",
        "content": "惊蛰春雷乍动，阳气升发加速，肝气旺盛。中医认为春应肝，此时宜养肝护肝、清肝明目，多食绿色蔬菜及甘味食物以柔肝缓急。",
        "recommended_foods": json.dumps({"ingredients": ["菠菜", "芹菜", "枸杞", "猪肝", "蜂蜜", "山药"], "recipes": [{"name": "枸杞菠菜猪肝汤", "description": "猪肝切片焯水，与菠菜、枸杞同煮，加姜丝调味", "benefits": "养肝明目，补血滋阴"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣燥热食物", "过量白酒", "油炸膨化食品"]}),
        "applicable_constitutions": json.dumps(["阴虚质", "平和质", "血瘀质"]),
        "season": "春季",
        "solar_term": "惊蛰"
    },
    {
        "category": "节气",
        "sub_category": "春分",
        "title": "春分节气饮食指南",
        "content": "春分昼夜均等，阴阳平衡。《素问》云「谨察阴阳所在而调之，以平为期」。饮食宜平调寒热，不宜偏颇，以清淡平和为主。",
        "recommended_foods": json.dumps({"ingredients": ["荠菜", "香椿", "蜂蜜", "红枣", "春笋", "鸡蛋"], "recipes": [{"name": "荠菜豆腐羹", "description": "荠菜洗净切碎，嫩豆腐切丁，同煮勾薄芡", "benefits": "清热平肝，调和脾胃"}]}),
        "avoid_foods": json.dumps({"items": ["大热大寒食物", "过度滋补品", "辛辣厚味"]}),
        "applicable_constitutions": json.dumps(["平和质", "气郁质", "阴虚质"]),
        "season": "春季",
        "solar_term": "春分"
    },
    {
        "category": "节气",
        "sub_category": "清明",
        "title": "清明节气饮食指南",
        "content": "清明时节清气上升，气候清爽。宜柔肝养肺，多食柔润清补之品。传统食俗有青团等应节食物，需注意适量以免碍胃。",
        "recommended_foods": json.dumps({"ingredients": ["荠菜", "菊花", "银耳", "百合", "山药", "绿茶"], "recipes": [{"name": "菊花银耳羹", "description": "银耳泡发撕小朵，加冰糖炖至软糯，撒入菊花瓣", "benefits": "清热明目，润肺养阴"}]}),
        "avoid_foods": json.dumps({"items": ["发物（过敏者慎食）", "过甜糯米制品", "辛辣刺激食物"]}),
        "applicable_constitutions": json.dumps(["特禀质", "阴虚质", "平和质"]),
        "season": "春季",
        "solar_term": "清明"
    },
    {
        "category": "节气",
        "sub_category": "谷雨",
        "title": "谷雨节气饮食指南",
        "content": "谷雨为春季最后一个节气，雨量充沛，「雨生百谷」。湿气加重，宜健脾利湿、养肝护肝，为入夏做好身体准备。",
        "recommended_foods": json.dumps({"ingredients": ["赤小豆", "薏米", "冬瓜", "鲫鱼", "茯苓", "香椿"], "recipes": [{"name": "赤小豆鲫鱼汤", "description": "赤小豆提前浸泡，鲫鱼煎至两面金黄，同煮至汤白", "benefits": "健脾利水，祛湿消肿"}]}),
        "avoid_foods": json.dumps({"items": ["生冷瓜果", "肥甘厚味", "冰镇饮品"]}),
        "applicable_constitutions": json.dumps(["痰湿质", "湿热质", "气虚质"]),
        "season": "春季",
        "solar_term": "谷雨"
    },

    # ---------- 夏季（6 节气）养生原则：清心消暑，养阴生津 ----------
    {
        "category": "节气",
        "sub_category": "立夏",
        "title": "立夏节气饮食指南",
        "content": "立夏为夏季之始，《素问》云「夏三月，此谓蕃秀」，阳气最旺。夏气通于心，饮食宜养心安神，增酸减苦以助肝气、益心气。",
        "recommended_foods": json.dumps({"ingredients": ["莲子", "百合", "小麦", "桂圆", "小米", "酸梅"], "recipes": [{"name": "莲子百合小米粥", "description": "莲子去芯，百合洗净，与小米同煮成粥", "benefits": "养心安神，健脾和胃"}]}),
        "avoid_foods": json.dumps({"items": ["过苦食物", "辛辣燥热食物", "过量冷饮"]}),
        "applicable_constitutions": json.dumps(["平和质", "阴虚质", "气虚质"]),
        "season": "夏季",
        "solar_term": "立夏"
    },
    {
        "category": "节气",
        "sub_category": "小满",
        "title": "小满节气饮食指南",
        "content": "小满时节，气温升高，雨水增多，湿热交织。宜食清热利湿之品，助体内湿热排出。",
        "recommended_foods": json.dumps({"ingredients": ["苦瓜", "冬瓜", "薏仁", "绿豆", "莲藕"], "recipes": [{"name": "苦瓜炒蛋", "description": "苦瓜切片盐渍去苦，与鸡蛋同炒", "benefits": "清心明目，降血糖"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣食物", "油炸食物", "生冷食物"]}),
        "applicable_constitutions": json.dumps(["平和质", "痰湿质", "湿热质"]),
        "season": "夏季",
        "solar_term": "小满"
    },
    {
        "category": "节气",
        "sub_category": "芒种",
        "title": "芒种节气饮食指南",
        "content": "芒种时节，梅雨季开始，湿热交蒸。宜食清淡易消化、健脾祛湿之品，饮食宜清补不宜过腻。",
        "recommended_foods": json.dumps({"ingredients": ["山药", "茯苓", "赤小豆", "鸭肉", "薏仁"], "recipes": [{"name": "山药茯苓粥", "description": "山药、茯苓、粳米同煮至软烂", "benefits": "健脾益气，利水渗湿"}]}),
        "avoid_foods": json.dumps({"items": ["油腻食物", "甜腻食物", "冷饮"]}),
        "applicable_constitutions": json.dumps(["气虚质", "阳虚质", "痰湿质"]),
        "season": "夏季",
        "solar_term": "芒种"
    },
    {
        "category": "节气",
        "sub_category": "夏至",
        "title": "夏至节气饮食指南",
        "content": "夏至阳极阴生，《素问》云「春夏养阳」。此时天气最热，但阴气始生，饮食宜清心泻火、养阴生津，不可过度贪凉伤及初生之阴。",
        "recommended_foods": json.dumps({"ingredients": ["绿豆", "西瓜翠衣", "苦瓜", "乌梅", "荷叶", "丝瓜"], "recipes": [{"name": "荷叶绿豆粥", "description": "绿豆提前浸泡，与粳米同煮，荷叶盖面取其清香", "benefits": "清热解暑，生津止渴"}]}),
        "avoid_foods": json.dumps({"items": ["冰镇饮料大量饮用", "肥甘厚味", "过量辛辣"]}),
        "applicable_constitutions": json.dumps(["湿热质", "阴虚质", "平和质"]),
        "season": "夏季",
        "solar_term": "夏至"
    },
    {
        "category": "节气",
        "sub_category": "小暑",
        "title": "小暑节气饮食指南",
        "content": "小暑虽非最热，但暑热渐盛，湿气亦重。宜清热解暑、益气养阴，适当增加利水渗湿之品，以防暑湿伤身。",
        "recommended_foods": json.dumps({"ingredients": ["荷叶", "冬瓜", "丝瓜", "扁豆", "薏仁", "绿豆芽"], "recipes": [{"name": "冬瓜薏仁排骨汤", "description": "冬瓜连皮切块，与薏仁、排骨同炖至软烂", "benefits": "清热利尿，健脾祛湿"}]}),
        "avoid_foods": json.dumps({"items": ["过量冷饮冰品", "油腻烧烤", "辛辣厚味"]}),
        "applicable_constitutions": json.dumps(["湿热质", "痰湿质", "阴虚质"]),
        "season": "夏季",
        "solar_term": "小暑"
    },
    {
        "category": "节气",
        "sub_category": "大暑",
        "title": "大暑节气饮食指南",
        "content": "大暑为一年中最热之时，暑气夹湿最盛。饮食以清热解暑、健脾祛湿为要，适当食用芳香化湿之品如藿香、佩兰等。",
        "recommended_foods": json.dumps({"ingredients": ["绿豆", "薏仁", "冬瓜", "藿香", "荷叶", "鸭肉"], "recipes": [{"name": "绿豆薏仁汤", "description": "绿豆、薏仁提前浸泡，加水同煮至豆烂", "benefits": "清热解毒，利水祛湿"}]}),
        "avoid_foods": json.dumps({"items": ["油炸食品", "过量肉类", "冰品过度"]}),
        "applicable_constitutions": json.dumps(["湿热质", "痰湿质", "阴虚质"]),
        "season": "夏季",
        "solar_term": "大暑"
    },

    # ---------- 秋季（6 节气）养生原则：润肺养阴，收敛神气 ----------
    {
        "category": "节气",
        "sub_category": "立秋",
        "title": "立秋节气饮食指南",
        "content": "立秋为秋季之始，《素问》云「秋三月，此谓容平」。秋气通于肺，宜养肺润燥，少食辛辣以免耗伤肺阴，增酸以助收敛。",
        "recommended_foods": json.dumps({"ingredients": ["梨", "银耳", "百合", "莲藕", "芝麻", "蜂蜜"], "recipes": [{"name": "冰糖雪梨银耳羹", "description": "银耳泡发撕小朵，雪梨去皮切块，加冰糖炖至软糯", "benefits": "润肺止咳，生津润燥"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣燥热", "煎炸烧烤", "过量葱姜蒜"]}),
        "applicable_constitutions": json.dumps(["阴虚质", "平和质", "气虚质"]),
        "season": "秋季",
        "solar_term": "立秋"
    },
    {
        "category": "节气",
        "sub_category": "处暑",
        "title": "处暑节气饮食指南",
        "content": "处暑暑气渐消，但秋燥渐起。宜养阴润燥，适当增加滋阴润肺之品。「秋瓜坏肚」，西瓜等寒凉瓜果此时不宜多食。",
        "recommended_foods": json.dumps({"ingredients": ["鸭肉", "银耳", "蜂蜜", "梨", "莲藕", "百合"], "recipes": [{"name": "老鸭冬瓜汤", "description": "老鸭焯水去腥，与冬瓜、薏仁同炖两小时", "benefits": "滋阴清热，利水消肿"}]}),
        "avoid_foods": json.dumps({"items": ["西瓜过多", "冰镇冷饮", "辛辣烧烤"]}),
        "applicable_constitutions": json.dumps(["阴虚质", "湿热质", "平和质"]),
        "season": "秋季",
        "solar_term": "处暑"
    },
    {
        "category": "节气",
        "sub_category": "白露",
        "title": "白露节气饮食指南",
        "content": "白露昼夜温差加大，秋燥明显。民间有「白露不露」之说，饮食宜滋阴润肺，兼顾健脾以防秋凉伤胃。",
        "recommended_foods": json.dumps({"ingredients": ["百合", "山药", "梨", "银耳", "莲子", "龙眼"], "recipes": [{"name": "百合山药粥", "description": "山药去皮切块，鲜百合洗净，与粳米同煮", "benefits": "润肺止咳，健脾益气"}]}),
        "avoid_foods": json.dumps({"items": ["寒凉海鲜", "辛辣食物", "冰镇饮品"]}),
        "applicable_constitutions": json.dumps(["阴虚质", "气虚质", "平和质"]),
        "season": "秋季",
        "solar_term": "白露"
    },
    {
        "category": "节气",
        "sub_category": "秋分",
        "title": "秋分节气饮食指南",
        "content": "秋分昼夜等长，养生讲究阴阳平衡。秋燥已深，宜滋阴润燥为重，多食柔润之品，同时适当温补以防秋凉。",
        "recommended_foods": json.dumps({"ingredients": ["芝麻", "核桃", "糯米", "蜂蜜", "梨", "银耳"], "recipes": [{"name": "芝麻核桃糊", "description": "黑芝麻、核桃仁炒香磨粉，糯米粉炒熟，开水冲调加蜂蜜", "benefits": "滋阴润燥，补肾益精"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣食物过食", "油炸干燥食品", "过度冷饮"]}),
        "applicable_constitutions": json.dumps(["阴虚质", "气虚质", "平和质"]),
        "season": "秋季",
        "solar_term": "秋分"
    },
    {
        "category": "节气",
        "sub_category": "寒露",
        "title": "寒露节气饮食指南",
        "content": "寒露气温骤降，秋燥与秋寒并存。宜养阴防燥、润肺益胃，饮食应在养阴润燥基础上适当增加温热之品。",
        "recommended_foods": json.dumps({"ingredients": ["芝麻", "山药", "红枣", "莲子", "核桃", "栗子"], "recipes": [{"name": "红枣山药炖鸡汤", "description": "鸡肉焯水，山药去皮切块，与红枣、生姜同炖", "benefits": "健脾益气，温润不燥"}]}),
        "avoid_foods": json.dumps({"items": ["生冷食物", "寒性水果过食", "辛辣伤阴"]}),
        "applicable_constitutions": json.dumps(["气虚质", "阳虚质", "平和质"]),
        "season": "秋季",
        "solar_term": "寒露"
    },
    {
        "category": "节气",
        "sub_category": "霜降",
        "title": "霜降节气饮食指南",
        "content": "霜降为秋季最后一个节气，天气渐寒，秋燥明显。民间有「补冬不如补霜降」之说，宜滋阴润肺、健脾养胃，为入冬打基础。",
        "recommended_foods": json.dumps({"ingredients": ["白萝卜", "梨", "柿子", "牛肉", "山药", "莲藕"], "recipes": [{"name": "白萝卜牛肉汤", "description": "牛肉焯水，白萝卜切滚刀块，加姜片同炖至软烂", "benefits": "健脾养胃，补气养血"}]}),
        "avoid_foods": json.dumps({"items": ["寒凉生冷食物", "柿子空腹食用", "辛辣伤阴食品"]}),
        "applicable_constitutions": json.dumps(["气虚质", "阳虚质", "平和质"]),
        "season": "秋季",
        "solar_term": "霜降"
    },

    # ---------- 冬季（6 节气）养生原则：温补肾阳，藏精养阴 ----------
    {
        "category": "节气",
        "sub_category": "立冬",
        "title": "立冬节气饮食指南",
        "content": "立冬为冬季之始，《素问》云「冬三月，此谓闭藏」。冬气通于肾，宜温补肾阳，少食咸味以防伤肾，适当增苦以养心气。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "核桃", "黑芝麻", "枸杞", "黑豆", "山药"], "recipes": [{"name": "当归生姜羊肉汤", "description": "羊肉焯水，与当归、生姜同炖至酥烂", "benefits": "温补肾阳，散寒暖身"}]}),
        "avoid_foods": json.dumps({"items": ["生冷寒凉食物", "过咸腌制食品", "冰品冷饮"]}),
        "applicable_constitutions": json.dumps(["阳虚质", "气虚质", "血瘀质"]),
        "season": "冬季",
        "solar_term": "立冬"
    },
    {
        "category": "节气",
        "sub_category": "小雪",
        "title": "小雪节气饮食指南",
        "content": "小雪天气渐寒，宜温补益肾，增强御寒能力。适当食用高热量、高蛋白食物以补充冬季能量消耗，注意荤素搭配。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "黑豆", "红枣", "桂圆", "核桃", "糯米"], "recipes": [{"name": "黑豆红枣粥", "description": "黑豆提前浸泡，与红枣、糯米同煮至豆烂", "benefits": "补肾益气，温阳暖身"}]}),
        "avoid_foods": json.dumps({"items": ["寒凉生冷", "冰镇饮品", "过咸食物"]}),
        "applicable_constitutions": json.dumps(["阳虚质", "气虚质", "平和质"]),
        "season": "冬季",
        "solar_term": "小雪"
    },
    {
        "category": "节气",
        "sub_category": "大雪",
        "title": "大雪节气饮食指南",
        "content": "大雪寒气更甚，为进补最佳时节。宜温补助阳、补肾壮骨，多食温性食物以抵御严寒，同时搭配萝卜等通利之品以防补而过腻。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "牛肉", "核桃", "黑木耳", "山药", "白萝卜"], "recipes": [{"name": "萝卜炖羊肉", "description": "羊肉焯水去膻，与白萝卜、生姜、枸杞同炖两小时", "benefits": "温阳散寒，消食导滞"}]}),
        "avoid_foods": json.dumps({"items": ["生冷食物", "冰镇饮料", "过食辛辣以致上火"]}),
        "applicable_constitutions": json.dumps(["阳虚质", "气虚质", "血瘀质"]),
        "season": "冬季",
        "solar_term": "大雪"
    },
    {
        "category": "节气",
        "sub_category": "冬至",
        "title": "冬至节气饮食指南",
        "content": "冬至一阳生，为阴气至极、阳气始生之时，是冬季进补的重要节点。民间有「冬至大如年」之说，宜温阳补肾、益精填髓。北方食饺子、南方食汤圆皆为应节之俗。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "核桃", "黑芝麻", "枸杞", "山药", "栗子"], "recipes": [{"name": "核桃枸杞炖羊肉", "description": "羊肉焯水，与核桃仁、枸杞、山药同炖至酥烂", "benefits": "温补肾阳，益精养血"}]}),
        "avoid_foods": json.dumps({"items": ["寒凉生冷食物", "过咸腌制食品", "暴饮暴食"]}),
        "applicable_constitutions": json.dumps(["阳虚质", "气虚质", "血瘀质"]),
        "season": "冬季",
        "solar_term": "冬至"
    },
    {
        "category": "节气",
        "sub_category": "小寒",
        "title": "小寒节气饮食指南",
        "content": "小寒虽名「小」，实则常为一年中最寒冷之时。宜温补驱寒，重在温肾阳、健脾胃，饮食以温热熟食为主。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "生姜", "红枣", "桂圆", "糯米", "当归"], "recipes": [{"name": "生姜红枣茶", "description": "生姜切片，红枣去核，加水煮沸后小火煮15分钟，加红糖调味", "benefits": "温中散寒，补气养血"}]}),
        "avoid_foods": json.dumps({"items": ["生冷瓜果", "冰镇饮品", "寒凉海鲜"]}),
        "applicable_constitutions": json.dumps(["阳虚质", "气虚质", "平和质"]),
        "season": "冬季",
        "solar_term": "小寒"
    },
    {
        "category": "节气",
        "sub_category": "大寒",
        "title": "大寒节气饮食指南",
        "content": "大寒为冬季最后一个节气，寒气最重，但阳气已在暗中萌动。宜温补脾肾以御寒，同时适当增加辛散之品以备春季升发。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "鸡肉", "山药", "枸杞", "生姜", "红枣"], "recipes": [{"name": "山药枸杞炖鸡汤", "description": "老母鸡焯水，山药去皮切块，加枸杞、姜片炖两小时", "benefits": "温中益气，补脾养肾"}]}),
        "avoid_foods": json.dumps({"items": ["生冷寒凉食物", "冰镇饮品", "暴饮暴食"]}),
        "applicable_constitutions": json.dumps(["阳虚质", "气虚质", "平和质"]),
        "season": "冬季",
        "solar_term": "大寒"
    },

    # ============================================================
    # 二、四季养生要点（春、夏、秋、冬各1条）
    # ============================================================
    {
        "category": "季节",
        "sub_category": "春季",
        "title": "春季养生饮食要点",
        "content": "春属木，对应肝脏。《黄帝内经》云「春三月，此谓发陈，天地俱生，万物以荣」。春季养生重在养肝护肝，宜辛甘发散以助阳气升发，少食酸收之品，多食绿色蔬菜、芽菜类以应春气。",
        "recommended_foods": json.dumps({"ingredients": ["韭菜", "菠菜", "荠菜", "豆芽", "春笋", "枸杞", "红枣"], "recipes": [{"name": "韭菜炒核桃仁", "description": "韭菜切段，核桃仁略炒，同炒加盐调味", "benefits": "温阳补肾，助肝气升发"}, {"name": "枸杞菊花茶", "description": "枸杞10克、菊花5朵，沸水冲泡代茶饮", "benefits": "养肝明目，清热降火"}]}),
        "avoid_foods": json.dumps({"items": ["过度酸味食物", "油腻厚味", "大辛大热食物"]}),
        "applicable_constitutions": json.dumps(["平和质", "气郁质", "阴虚质"]),
        "season": "春季",
        "solar_term": None
    },
    {
        "category": "季节",
        "sub_category": "夏季",
        "title": "夏季养生饮食要点",
        "content": "夏季属火，对应心脏。《素问》云「夏三月，此谓蕃秀」。饮食宜清心消暑，多食瓜果蔬菜，少食辛辣以免助热，适当增酸以收敛心气。",
        "recommended_foods": json.dumps({"ingredients": ["西瓜", "黄瓜", "番茄", "莲子", "百合", "绿豆"], "recipes": [{"name": "莲子百合粥", "description": "莲子去芯、百合洗净，与大米熬粥", "benefits": "养心安神，清热解暑"}, {"name": "绿豆汤", "description": "绿豆洗净加水煮至开花，可加冰糖调味", "benefits": "清热解毒，消暑利水"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣烧烤", "高度白酒", "麻辣火锅"]}),
        "applicable_constitutions": json.dumps(["平和质", "阴虚质", "湿热质"]),
        "season": "夏季",
        "solar_term": None
    },
    {
        "category": "季节",
        "sub_category": "秋季",
        "title": "秋季养生饮食要点",
        "content": "秋属金，对应肺脏。《素问》云「秋三月，此谓容平，天气以急，地气以明」。秋季养生重在养肺润燥，宜滋阴润肺，少食辛辣以护肺阴，适当食酸以助收敛。",
        "recommended_foods": json.dumps({"ingredients": ["梨", "银耳", "百合", "芝麻", "蜂蜜", "莲藕", "山药"], "recipes": [{"name": "银耳百合莲子羹", "description": "银耳泡发撕小朵，百合、莲子同炖至软糯，加冰糖", "benefits": "滋阴润肺，养心安神"}, {"name": "蜂蜜蒸梨", "description": "雪梨去核，填入蜂蜜，隔水蒸30分钟", "benefits": "润肺止咳，生津止渴"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣燥热食物", "煎炸烧烤", "过多葱姜蒜"]}),
        "applicable_constitutions": json.dumps(["阴虚质", "平和质", "气虚质"]),
        "season": "秋季",
        "solar_term": None
    },
    {
        "category": "季节",
        "sub_category": "冬季",
        "title": "冬季养生饮食要点",
        "content": "冬属水，对应肾脏。《素问》云「冬三月，此谓闭藏，水冰地坼，无扰乎阳」。冬季养生重在温补肾阳，宜食温热熟食以御寒，少食咸味以免伤肾，适当食苦以养心。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "牛肉", "核桃", "黑芝麻", "黑豆", "枸杞", "山药"], "recipes": [{"name": "山药羊肉汤", "description": "羊肉焯水去膻，山药去皮切块，加生姜、枸杞同炖", "benefits": "温补肾阳，益气健脾"}, {"name": "黑芝麻糊", "description": "黑芝麻炒香磨粉，糯米粉炒熟，加开水冲调", "benefits": "补肾益精，润肠通便"}]}),
        "avoid_foods": json.dumps({"items": ["生冷寒凉食物", "冰镇饮品", "过咸腌制食品"]}),
        "applicable_constitutions": json.dumps(["阳虚质", "气虚质", "血瘀质"]),
        "season": "冬季",
        "solar_term": None
    },

    # ============================================================
    # 三、9 种体质饮食调养（依据《中医体质分类与判定》ZYYXH/T157-2009）
    # ============================================================
    {
        "category": "体质",
        "sub_category": "平和质",
        "title": "平和体质饮食调养",
        "content": "平和质为阴阳气血调和之体，是《中医体质分类与判定》标准中最为理想的体质类型。特征：体态适中、面色红润、精力充沛。饮食原则为均衡膳食、五味调和，不宜偏嗜。参考《中国居民膳食指南（2022）》均衡营养建议。",
        "recommended_foods": json.dumps({"ingredients": ["全谷物", "深色蔬菜", "新鲜水果", "优质蛋白质", "坚果"], "recipes": [{"name": "五彩蔬菜沙拉", "description": "西兰花、胡萝卜、紫甘蓝、番茄、黄瓜切块，加橄榄油、柠檬汁拌匀", "benefits": "营养均衡，补充多种维生素"}]}),
        "avoid_foods": json.dumps({"items": ["无特殊禁忌，注意不过量偏嗜某一类食物"]}),
        "applicable_constitutions": json.dumps(["平和质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "气虚质",
        "title": "气虚体质饮食调养",
        "content": "气虚质以元气不足、疲乏气短为主要特征，在《中医体质分类与判定》标准中表现为语声低微、易出汗、舌淡红。饮食原则为益气健脾，多食甘温益气之品。",
        "recommended_foods": json.dumps({"ingredients": ["山药", "黄芪", "党参", "红枣", "糯米", "鸡肉", "小米"], "recipes": [{"name": "黄芪红枣炖鸡汤", "description": "母鸡焯水，加黄芪15克、红枣10枚、生姜3片同炖两小时", "benefits": "补中益气，健脾养胃"}]}),
        "avoid_foods": json.dumps({"items": ["生冷寒凉食物", "萝卜等耗气之品过食", "空心菜等滑利之品"]}),
        "applicable_constitutions": json.dumps(["气虚质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "阳虚质",
        "title": "阳虚体质饮食调养",
        "content": "阳虚质以阳气不足、畏寒怕冷为主要特征，在《中医体质分类与判定》标准中表现为手足不温、喜热饮食。饮食原则为温补阳气，多食温热之品，忌生冷寒凉。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "生姜", "桂圆", "红枣", "核桃"], "recipes": [{"name": "当归生姜羊肉汤", "description": "当归、生姜与羊肉同炖至酥烂", "benefits": "温中散寒，补气养血"}]}),
        "avoid_foods": json.dumps({"items": ["西瓜", "梨", "冷饮", "生鱼片"]}),
        "applicable_constitutions": json.dumps(["阳虚质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "阴虚质",
        "title": "阴虚体质饮食调养",
        "content": "阴虚质以阴液亏少、口燥咽干为主要特征，在《中医体质分类与判定》标准中表现为手足心热、盗汗、大便干燥。饮食原则为滋阴清热，多食甘凉滋润之品。",
        "recommended_foods": json.dumps({"ingredients": ["银耳", "百合", "梨", "鸭肉", "枸杞", "蜂蜜", "莲藕"], "recipes": [{"name": "银耳枸杞羹", "description": "银耳泡发撕小朵，与枸杞、冰糖同炖至浓稠", "benefits": "滋阴润燥，养肝明目"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣燥热食物", "油炸烧烤", "羊肉等温燥之品"]}),
        "applicable_constitutions": json.dumps(["阴虚质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "痰湿质",
        "title": "痰湿体质饮食调养",
        "content": "痰湿质以痰湿凝聚、形体肥胖为主要特征，在《中医体质分类与判定》标准中表现为腹部肥满、口黏苔腻。饮食原则为健脾利湿、化痰泄浊，宜清淡。",
        "recommended_foods": json.dumps({"ingredients": ["薏苡仁", "赤小豆", "冬瓜", "荷叶", "白萝卜"], "recipes": [{"name": "冬瓜薏米汤", "description": "冬瓜连皮切块，与薏米同煮至软烂", "benefits": "健脾利湿，化痰消脂"}]}),
        "avoid_foods": json.dumps({"items": ["肥肉", "奶油", "甜食", "啤酒"]}),
        "applicable_constitutions": json.dumps(["痰湿质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "湿热质",
        "title": "湿热体质饮食调养",
        "content": "湿热质以湿热内蕴、面垢油光为主要特征，在《中医体质分类与判定》标准中表现为口苦口干、大便黏滞。饮食原则为清热利湿，多食甘寒清淡之品。",
        "recommended_foods": json.dumps({"ingredients": ["绿豆", "薏仁", "苦瓜", "冬瓜", "赤小豆", "黄瓜", "莲藕"], "recipes": [{"name": "薏仁绿豆汤", "description": "薏仁、绿豆提前浸泡，加水同煮至豆烂", "benefits": "清热利湿，解毒消肿"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣燥热食物", "肥甘厚味", "烟酒", "甜腻糕点"]}),
        "applicable_constitutions": json.dumps(["湿热质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "血瘀质",
        "title": "血瘀体质饮食调养",
        "content": "血瘀质以血行不畅、肤色晦暗为主要特征，在《中医体质分类与判定》标准中表现为舌质紫黯、易出现瘀斑。饮食原则为活血化瘀，多食行气活血之品。",
        "recommended_foods": json.dumps({"ingredients": ["山楂", "黑木耳", "洋葱", "茄子", "醋", "玫瑰花", "油菜"], "recipes": [{"name": "黑木耳炒山药", "description": "黑木耳泡发撕小朵，山药切片，同炒加醋调味", "benefits": "活血化瘀，健脾益气"}]}),
        "avoid_foods": json.dumps({"items": ["肥甘厚腻食物", "过度冷饮", "过咸食物"]}),
        "applicable_constitutions": json.dumps(["血瘀质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "气郁质",
        "title": "气郁体质饮食调养",
        "content": "气郁质以气机郁滞、神情抑郁为主要特征，在《中医体质分类与判定》标准中表现为情绪低沉、胸胁胀满。饮食原则为疏肝理气、解郁安神。",
        "recommended_foods": json.dumps({"ingredients": ["佛手", "玫瑰花", "柑橘", "小麦", "百合", "莲子", "小米"], "recipes": [{"name": "玫瑰花茶", "description": "干玫瑰花5朵，沸水冲泡，可加蜂蜜调味，代茶饮", "benefits": "疏肝解郁，行气活血"}]}),
        "avoid_foods": json.dumps({"items": ["浓茶咖啡过量", "辛辣刺激食物", "过食油腻"]}),
        "applicable_constitutions": json.dumps(["气郁质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "特禀质",
        "title": "特禀体质饮食调养",
        "content": "特禀质（过敏体质）以先天失常、易过敏为主要特征，在《中医体质分类与判定》标准中表现为易对药物、食物、花粉等过敏。饮食原则为益气固表、增强免疫，避免已知过敏原。",
        "recommended_foods": json.dumps({"ingredients": ["黄芪", "白术", "山药", "红枣", "蜂蜜", "灵芝", "糯米"], "recipes": [{"name": "黄芪红枣粥", "description": "黄芪15克煎水取汁，与红枣、糯米同煮成粥", "benefits": "益气固表，增强体质"}]}),
        "avoid_foods": json.dumps({"items": ["个人已知过敏食物", "海鲜等发物（因人而异）", "含添加剂食品"]}),
        "applicable_constitutions": json.dumps(["特禀质"]),
        "season": None,
        "solar_term": None
    },
]

def init_data():
    db = SessionLocal()
    inserted = 0
    try:
        for item in data:
            exists = db.query(WellnessKnowledge).filter(
                WellnessKnowledge.category == item["category"],
                WellnessKnowledge.sub_category == item["sub_category"]
            ).first()
            if not exists:
                db.add(WellnessKnowledge(**item))
                inserted += 1
        db.commit()
        print(f"养生知识数据初始化完成：总 {len(data)} 条，本次新增 {inserted} 条")
    except Exception as e:
        db.rollback()
        print(f"数据插入失败: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    init_data()
