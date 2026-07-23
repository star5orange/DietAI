import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';

/// 根据物种字符串返回对应的图标
IconData getSpeciesIcon(String? species) {
  switch (species?.toLowerCase()) {
    case 'cat':
      return LucideIcons.cat;
    case 'dog':
      return LucideIcons.dog;
    default:
      return Icons.pets; // 兔子、仓鼠等通用宠物爪印图标
  }
}

/// 根据物种字符串返回对应的中文标签
String getSpeciesLabel(String? species) {
  switch (species?.toLowerCase()) {
    case 'cat':
      return '猫';
    case 'dog':
      return '狗';
    case 'rabbit':
      return '兔';
    case 'hamster':
      return '仓鼠';
    case 'bird':
      return '鸟';
    case 'fish':
      return '鱼';
    case 'turtle':
      return '龟';
    default:
      return species ?? '宠物';
  }
}
