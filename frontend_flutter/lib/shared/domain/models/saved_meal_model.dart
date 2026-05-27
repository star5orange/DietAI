/// 保存菜品营养信息
class SavedMealNutrition {
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final double dietaryFiber;
  final double sugar;
  final double sodium;
  final double cholesterol;
  final double vitaminA;
  final double vitaminC;
  final double vitaminD;
  final double calcium;
  final double iron;
  final double potassium;

  const SavedMealNutrition({
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.dietaryFiber,
    required this.sugar,
    required this.sodium,
    required this.cholesterol,
    required this.vitaminA,
    required this.vitaminC,
    required this.vitaminD,
    required this.calcium,
    required this.iron,
    required this.potassium,
  });

  factory SavedMealNutrition.fromJson(Map<String, dynamic> json) {
    return SavedMealNutrition(
      servingSize: (json['serving_size'] ?? 100.0).toDouble(),
      servingUnit: json['serving_unit'] ?? 'g',
      calories: (json['calories'] ?? 0.0).toDouble(),
      protein: (json['protein'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      carbohydrates: (json['carbohydrates'] ?? 0.0).toDouble(),
      dietaryFiber: (json['dietary_fiber'] ?? 0.0).toDouble(),
      sugar: (json['sugar'] ?? 0.0).toDouble(),
      sodium: (json['sodium'] ?? 0.0).toDouble(),
      cholesterol: (json['cholesterol'] ?? 0.0).toDouble(),
      vitaminA: (json['vitamin_a'] ?? 0.0).toDouble(),
      vitaminC: (json['vitamin_c'] ?? 0.0).toDouble(),
      vitaminD: (json['vitamin_d'] ?? 0.0).toDouble(),
      calcium: (json['calcium'] ?? 0.0).toDouble(),
      iron: (json['iron'] ?? 0.0).toDouble(),
      potassium: (json['potassium'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serving_size': servingSize,
      'serving_unit': servingUnit,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbohydrates': carbohydrates,
      'dietary_fiber': dietaryFiber,
      'sugar': sugar,
      'sodium': sodium,
      'cholesterol': cholesterol,
      'vitamin_a': vitaminA,
      'vitamin_c': vitaminC,
      'vitamin_d': vitaminD,
      'calcium': calcium,
      'iron': iron,
      'potassium': potassium,
    };
  }
}

/// 保存的菜品
class SavedMeal {
  final int id;
  final String mealName;
  final String? description;
  final String? imageUrl;
  final String? category;
  final List<String>? tags;
  final bool isPublic;
  final int usageCount;
  final int favoriteCount;
  final String createdAt;
  final String updatedAt;
  final SavedMealNutrition? nutrition;
  final bool? isFavorited;

  const SavedMeal({
    required this.id,
    required this.mealName,
    this.description,
    this.imageUrl,
    this.category,
    this.tags,
    required this.isPublic,
    required this.usageCount,
    required this.favoriteCount,
    required this.createdAt,
    required this.updatedAt,
    this.nutrition,
    this.isFavorited,
  });

  factory SavedMeal.fromJson(Map<String, dynamic> json) {
    return SavedMeal(
      id: json['id'] ?? 0,
      mealName: json['meal_name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      category: json['category'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      isPublic: json['is_public'] ?? false,
      usageCount: json['usage_count'] ?? 0,
      favoriteCount: json['favorite_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      nutrition: json['nutrition'] != null 
          ? SavedMealNutrition.fromJson(json['nutrition'])
          : null,
      isFavorited: json['is_favorited'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meal_name': mealName,
      'description': description,
      'image_url': imageUrl,
      'category': category,
      'tags': tags,
      'is_public': isPublic,
      'usage_count': usageCount,
      'favorite_count': favoriteCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'nutrition': nutrition?.toJson(),
      'is_favorited': isFavorited,
    };
  }

  /// 获取分类显示名称
  String get categoryDisplayName {
    switch (category) {
      case 'main_dish':
        return '主菜';
      case 'side_dish':
        return '配菜';
      case 'soup':
        return '汤类';
      case 'staple':
        return '主食';
      case 'snack':
        return '零食';
      case 'drink':
        return '饮品';
      case 'dessert':
        return '甜品';
      default:
        return category ?? '其他';
    }
  }

  /// 获取营养信息摘要
  String get nutritionSummary {
    if (nutrition == null) return '无营养信息';
    
    return '${nutrition!.calories.round()}kcal | '
           '蛋白质${nutrition!.protein.round()}g | '
           '脂肪${nutrition!.fat.round()}g | '
           '碳水${nutrition!.carbohydrates.round()}g';
  }
}

/// 创建保存菜品请求
class SavedMealCreate {
  final String mealName;
  final String? description;
  final String? imageUrl;
  final String? category;
  final List<String>? tags;
  final bool isPublic;
  final SavedMealNutrition nutrition;

  const SavedMealCreate({
    required this.mealName,
    this.description,
    this.imageUrl,
    this.category,
    this.tags,
    required this.isPublic,
    required this.nutrition,
  });

  factory SavedMealCreate.fromJson(Map<String, dynamic> json) {
    return SavedMealCreate(
      mealName: json['meal_name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      category: json['category'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      isPublic: json['is_public'] ?? false,
      nutrition: SavedMealNutrition.fromJson(json['nutrition']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meal_name': mealName,
      'description': description,
      'image_url': imageUrl,
      'category': category,
      'tags': tags,
      'is_public': isPublic,
      'nutrition': nutrition.toJson(),
    };
  }
}

/// 更新保存菜品请求
class SavedMealUpdate {
  final String? mealName;
  final String? description;
  final String? imageUrl;
  final String? category;
  final List<String>? tags;
  final bool? isPublic;
  final SavedMealNutrition? nutrition;

  const SavedMealUpdate({
    this.mealName,
    this.description,
    this.imageUrl,
    this.category,
    this.tags,
    this.isPublic,
    this.nutrition,
  });

  factory SavedMealUpdate.fromJson(Map<String, dynamic> json) {
    return SavedMealUpdate(
      mealName: json['meal_name'],
      description: json['description'],
      imageUrl: json['image_url'],
      category: json['category'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      isPublic: json['is_public'],
      nutrition: json['nutrition'] != null 
          ? SavedMealNutrition.fromJson(json['nutrition'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meal_name': mealName,
      'description': description,
      'image_url': imageUrl,
      'category': category,
      'tags': tags,
      'is_public': isPublic,
      'nutrition': nutrition?.toJson(),
    };
  }
}

/// 菜品分类枚举
enum MealCategory {
  mainDish('main_dish', '主菜'),
  sideDish('side_dish', '配菜'),
  soup('soup', '汤类'),
  staple('staple', '主食'),
  snack('snack', '零食'),
  drink('drink', '饮品'),
  dessert('dessert', '甜品');

  const MealCategory(this.value, this.displayName);
  
  final String value;
  final String displayName;

  static MealCategory? fromValue(String? value) {
    for (var category in MealCategory.values) {
      if (category.value == value) return category;
    }
    return null;
  }

  static List<String> get allValues => MealCategory.values.map((e) => e.value).toList();
  static List<String> get allDisplayNames => MealCategory.values.map((e) => e.displayName).toList();
}