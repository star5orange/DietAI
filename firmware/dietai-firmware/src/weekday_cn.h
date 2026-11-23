/**
 * 中文星期字符串 — UTF-8 显式字节，不受文件编码影响
 * efontCN_16 字体渲染 (LovyanGFX 内置)
 */
#ifndef WEEKDAY_CN_H
#define WEEKDAY_CN_H

static const char* weekdayCN(int wday) {
    static const char* tbl[] = {
        "\xE5\x91\xA8\xE6\x97\xA5",  // 周日
        "\xE5\x91\xA8\xE4\xB8\x80",  // 周一
        "\xE5\x91\xA8\xE4\xBA\x8C",  // 周二
        "\xE5\x91\xA8\xE4\xB8\x89",  // 周三
        "\xE5\x91\xA8\xE5\x9B\x9B",  // 周四
        "\xE5\x91\xA8\xE4\xBA\x94",  // 周五
        "\xE5\x91\xA8\xE5\x85\xAD",  // 周六
    };
    return tbl[wday % 7];
}

#endif
