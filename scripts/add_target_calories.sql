-- 添加 target_calories 字段到 user_profiles 表
-- 执行方式：在 DBeaver 或其他数据库管理工具中执行

-- 1. 添加字段（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_profiles'
        AND column_name = 'target_calories'
    ) THEN
        ALTER TABLE user_profiles ADD COLUMN target_calories INTEGER DEFAULT 2000;
        RAISE NOTICE '成功添加 target_calories 字段';
    ELSE
        RAISE NOTICE 'target_calories 字段已存在';
    END IF;
END $$;

-- 2. 更新现有记录的默认值
UPDATE user_profiles
SET target_calories = 2000
WHERE target_calories IS NULL;

-- 3. 验证字段是否添加成功
SELECT
    column_name,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_profiles'
AND column_name = 'target_calories';